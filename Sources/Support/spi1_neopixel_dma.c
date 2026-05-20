/*
 * spi1_neopixel_dma.c — Adafruit NeoPixel_ZeroDMA pattern for one QT Py pixel.
 *
 * SPI runs continuously from a looping DMAC descriptor. Trailing zero bytes in the
 * buffer provide WS2812 latch time (~300 µs with 90 bytes @ 2.4 MHz) so MOSI is
 * not left idle high between updates.
 */

#include "spi1_neopixel_dma.h"

#include <sam.h>
#include <string.h>

#define NEO_DMA_CHANNEL 0
#define NEO_COLOR_SPI_BYTES 9
#define NEO_LATCH_SPI_BYTES 90
#define NEO_DMA_BUF_LEN (NEO_COLOR_SPI_BYTES + NEO_LATCH_SPI_BYTES)

static uint8_t neo_dma_buf[NEO_DMA_BUF_LEN] __attribute__((aligned(16)));
static DmacDescriptor neo_desc[1] __attribute__((aligned(16)));
static DmacDescriptor neo_wb[1] __attribute__((aligned(16)));

static bool neo_dma_running;

static void neo_expand_byte(uint8_t value, uint8_t *out) {
    uint32_t acc = 0;
    for (int i = 0; i < 8; i++) {
        const uint8_t one = (value & 0x80u) != 0u;
        value <<= 1;
        acc = (acc << 3) | (one ? 0b110u : 0b100u);
    }
    out[0] = (uint8_t)((acc >> 16) & 0xFFu);
    out[1] = (uint8_t)((acc >> 8) & 0xFFu);
    out[2] = (uint8_t)(acc & 0xFFu);
}

static void neo_build_color(uint8_t green, uint8_t red, uint8_t blue) {
    neo_expand_byte(green, &neo_dma_buf[0]);
    neo_expand_byte(red, &neo_dma_buf[3]);
    neo_expand_byte(blue, &neo_dma_buf[6]);
}

static void sercom1_spi_configure(void) {
    PM->APBCMASK.reg |= PM_APBCMASK_SERCOM1;

    SERCOM1->SPI.CTRLA.bit.ENABLE = 0;
    while (SERCOM1->SPI.SYNCBUSY.bit.ENABLE) {
    }

    SERCOM1->SPI.CTRLA.bit.SWRST = 1;
    while (SERCOM1->SPI.SYNCBUSY.bit.SWRST || SERCOM1->SPI.CTRLA.bit.SWRST) {
    }

    SERCOM1->SPI.CTRLA.reg =
        SERCOM_SPI_CTRLA_DOPO(1) | /* MOSI PAD2, SCK PAD3 */
        SERCOM_SPI_CTRLA_DIPO(1) | /* unused MISO pad */
        SERCOM_SPI_CTRLA_MODE(3);  /* SPI master, mode 0 (CPOL/CPHA clear) */

    SERCOM1->SPI.CTRLB.reg = SERCOM_SPI_CTRLB_CHSIZE(0); /* 8-bit */
    while (SERCOM1->SPI.SYNCBUSY.bit.CTRLB) {
    }

    SERCOM1->SPI.BAUD.reg = 9; /* 48 MHz / 20 ≈ 2.4 MHz */

    SERCOM1->SPI.CTRLA.bit.ENABLE = 1;
    while (SERCOM1->SPI.SYNCBUSY.bit.ENABLE) {
    }

    while (SERCOM1->SPI.INTFLAG.bit.RXC) {
        (void)SERCOM1->SPI.DATA.reg;
    }
    SERCOM1->SPI.INTFLAG.reg = SERCOM_SPI_INTFLAG_TXC;
}

static void dmac_configure_loop(void) {
    PM->AHBMASK.reg |= PM_AHBMASK_DMAC;
    PM->APBBMASK.reg |= PM_APBBMASK_DMAC;

    DMAC->CTRL.bit.DMAENABLE = 0;
    DMAC->CTRL.bit.SWRST = 1;
    while (DMAC->CTRL.bit.SWRST) {
    }

    DMAC->BASEADDR.reg = (uint32_t)neo_desc;
    DMAC->WRBADDR.reg = (uint32_t)neo_wb;

    memset(neo_desc, 0, sizeof(neo_desc));
    memset(neo_wb, 0, sizeof(neo_wb));

    DmacDescriptor *const d = &neo_desc[0];

    d->BTCTRL.bit.VALID = 1;
    d->BTCTRL.bit.EVOSEL = DMAC_BTCTRL_EVOSEL_DISABLE_Val;
    d->BTCTRL.bit.BLOCKACT = DMAC_BTCTRL_BLOCKACT_NOACT_Val;
    d->BTCTRL.bit.BEATSIZE = DMAC_BTCTRL_BEATSIZE_BYTE_Val;
    d->BTCTRL.bit.SRCINC = 1;
    d->BTCTRL.bit.DSTINC = 0;

    d->BTCNT.reg = NEO_DMA_BUF_LEN;
    d->SRCADDR.reg = (uint32_t)neo_dma_buf + NEO_DMA_BUF_LEN;
    d->DSTADDR.reg = (uint32_t)&SERCOM1->SPI.DATA.reg;
    d->DESCADDR.reg = (uint32_t)d;

    DMAC->CTRL.reg = DMAC_CTRL_DMAENABLE | DMAC_CTRL_LVLEN(0xF);

    DMAC->CHID.reg = DMAC_CHID_ID(NEO_DMA_CHANNEL);
    DMAC->CHCTRLB.reg =
        DMAC_CHCTRLB_LVL(0) |
        DMAC_CHCTRLB_TRIGSRC(SERCOM1_DMAC_ID_TX) |
        DMAC_CHCTRLB_TRIGACT_BEAT;

    DMAC->CHCTRLA.bit.ENABLE = 1;

    DMAC->SWTRIGCTRL.reg = (1u << NEO_DMA_CHANNEL);
}

bool spi1_neopixel_dma_begin(void) {
    if (neo_dma_running) {
        return true;
    }

    memset(neo_dma_buf, 0, sizeof(neo_dma_buf));
    neo_build_color(0, 0, 0);

    sercom1_spi_configure();
    dmac_configure_loop();

    neo_dma_running = true;
    return true;
}

void spi1_neopixel_dma_set_pixel(uint8_t green, uint8_t red, uint8_t blue) {
    if (!neo_dma_running) {
        return;
    }

    uint32_t primask = __get_PRIMASK();
    __disable_irq();
    neo_build_color(green, red, blue);
    if (!primask) {
        __enable_irq();
    }
}

bool spi1_neopixel_dma_is_running(void) { return neo_dma_running; }
