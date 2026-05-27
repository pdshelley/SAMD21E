/*
 * spi1_neopixel.c — SERCOM1 SPI + DMAC NeoPixel (CMSIS only).
 *
 * Swift SPI1.configure() HardFaults on M0+ when stepping PM/SERCOM/DMAC after USB
 * connect; this file mirrors the working Swift setup using direct register writes.
 */

#include <sam.h>
#include <stdbool.h>
#include <stdint.h>

extern void spi1_enable_generic_clocks(void);
extern void dmac_enable_clocks(void);

enum {
    NEO_COLOR_BYTES = 9,
    NEO_LATCH_BYTES = 90,
    NEO_FRAME_BYTES = NEO_COLOR_BYTES + NEO_LATCH_BYTES,
};

#define SERCOM1_DATA_ADDR ((uint32_t)&SERCOM1->SPI.DATA.reg)

static bool neo_ready;

static uint8_t neo_frame[NEO_FRAME_BYTES];

__attribute__((aligned(16))) static DmacDescriptor neo_desc;
__attribute__((aligned(16))) static DmacDescriptor neo_wb;

static void wait_sercom1_spi(void) {
    while (SERCOM1->SPI.SYNCBUSY.reg) {
    }
}

static void expand_ws2812_byte(uint8_t value, uint8_t *b0, uint8_t *b1, uint8_t *b2) {
    uint32_t acc = 0;
    uint8_t bits = value;
    for (unsigned i = 0; i < 8u; i++) {
        unsigned one = (bits & 0x80u) != 0u;
        acc = (acc << 3) | (one ? 0x6u : 0x4u);
        bits <<= 1;
    }
    *b0 = (uint8_t)((acc >> 16) & 0xFFu);
    *b1 = (uint8_t)((acc >> 8) & 0xFFu);
    *b2 = (uint8_t)(acc & 0xFFu);
}

static void build_color_frame(uint8_t red, uint8_t green, uint8_t blue) {
    expand_ws2812_byte(green, &neo_frame[0], &neo_frame[1], &neo_frame[2]);
    expand_ws2812_byte(red, &neo_frame[3], &neo_frame[4], &neo_frame[5]);
    expand_ws2812_byte(blue, &neo_frame[6], &neo_frame[7], &neo_frame[8]);
}

/* Pause looping DMA, rewrite color bytes, resume (avoids torn WS2812 frames). */
static void neo_dma_pause_and_update(uint8_t red, uint8_t green, uint8_t blue) {
    DMAC->CHID.reg = DMAC_CHID_ID(0);
    DMAC->CHCTRLA.reg &= (uint8_t)~DMAC_CHCTRLA_ENABLE;
    while (DMAC->CHCTRLA.bit.ENABLE) {
    }
    build_color_frame(red, green, blue);
    DMAC->CHCTRLA.reg |= DMAC_CHCTRLA_ENABLE;
    DMAC->SWTRIGCTRL.reg = 1u;
}

static void gpio_neopixel_pins(void) {
    PM->APBBMASK.reg |= PM_APBBMASK_PORT;

    /* PA15 NeoPixel power — GPIO out, high. */
    PORT->Group[0].DIRSET.reg = (1u << 15);
    PORT->Group[0].OUTSET.reg = (1u << 15);
    PORT->Group[0].PINCFG[15].reg = 0;

    /* PA18 MOSI, PA19 SCK — SERCOM1 mux C (PAD2/PAD3). */
    PORT->Group[0].PINCFG[18].reg = PORT_PINCFG_PMUXEN;
    PORT->Group[0].PINCFG[19].reg = PORT_PINCFG_PMUXEN;
    PORT->Group[0].PMUX[9].reg = PORT_PMUX_PMUXE(2) | PORT_PMUX_PMUXO(2);
    PORT->Group[0].DIRSET.reg = (1u << 18) | (1u << 19);
}

static void sercom1_spi_init(void) {
    SercomSpi *spi = &SERCOM1->SPI;

    spi1_enable_generic_clocks();

    spi->CTRLA.bit.ENABLE = 0;
    wait_sercom1_spi();

    spi->CTRLA.bit.SWRST = 1;
    while (spi->CTRLA.bit.SWRST) {
    }
    wait_sercom1_spi();

    spi->CTRLA.reg = SERCOM_SPI_CTRLA_MODE(SERCOM_SPI_CTRLA_MODE_SPI_MASTER_Val) |
                     SERCOM_SPI_CTRLA_DOPO(1);
    spi->CTRLB.reg = 0;
    wait_sercom1_spi();

    spi->BAUD.reg = 9;
    spi->CTRLA.bit.ENABLE = 1;
    wait_sercom1_spi();

    while (spi->INTFLAG.bit.RXC) {
        (void)spi->DATA.reg;
    }
    spi->INTFLAG.reg = SERCOM_SPI_INTFLAG_TXC;
}

static void dmac_neopixel_init(void) {
    uint32_t src_end = (uint32_t)(uintptr_t)&neo_frame[NEO_FRAME_BYTES];
    uint32_t desc_addr = (uint32_t)(uintptr_t)&neo_desc;

    dmac_enable_clocks();

    for (unsigned i = NEO_COLOR_BYTES; i < NEO_FRAME_BYTES; i++) {
        neo_frame[i] = 0;
    }
    build_color_frame(0, 0, 0);

    DMAC->CTRL.reg = DMAC_CTRL_SWRST;
    while (DMAC->CTRL.bit.SWRST) {
    }

    neo_desc.BTCTRL.reg =
        DMAC_BTCTRL_VALID | DMAC_BTCTRL_SRCINC | DMAC_BTCTRL_BEATSIZE_BYTE;
    neo_desc.BTCNT.reg = NEO_FRAME_BYTES;
    neo_desc.SRCADDR.reg = src_end;
    neo_desc.DSTADDR.reg = SERCOM1_DATA_ADDR;
    neo_desc.DESCADDR.reg = desc_addr;

    DMAC->BASEADDR.reg = desc_addr;
    DMAC->WRBADDR.reg = (uint32_t)(uintptr_t)&neo_wb;

    DMAC->CTRL.reg = DMAC_CTRL_DMAENABLE | DMAC_CTRL_LVLEN(0xF);

    DMAC->CHID.reg = DMAC_CHID_ID(0);
    DMAC->CHCTRLB.reg = DMAC_CHCTRLB_TRIGSRC(4) | DMAC_CHCTRLB_TRIGACT_BEAT;
    DMAC->CHCTRLA.reg = DMAC_CHCTRLA_ENABLE;

    DMAC->SWTRIGCTRL.reg = 1u;
}

bool spi1_neopixel_init(void) {
    if (neo_ready) {
        return true;
    }

    gpio_neopixel_pins();
    sercom1_spi_init();
    dmac_neopixel_init();
    neo_ready = true;
    return true;
}

bool spi1_neopixel_ready(void) {
    return neo_ready;
}

void spi1_neopixel_set_rgb(uint8_t red, uint8_t green, uint8_t blue) {
    if (!neo_ready) {
        return;
    }
    neo_dma_pause_and_update(red, green, blue);
}
