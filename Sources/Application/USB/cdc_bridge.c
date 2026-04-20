#include "cdc_bridge.h"
#include "tusb.h"
#include <sam.h>

void cdc_init(void) {
    // Configure PA24 (USB D−) and PA25 (USB D+): output low, no pull, then mux to peripheral G.
    // Setting direction/level before enabling PMUXEN matches the TinyUSB BSP reference sequence.
    PORT->Group[0].DIRSET.reg   = (1u << 24) | (1u << 25);
    PORT->Group[0].OUTCLR.reg   = (1u << 24) | (1u << 25);
    PORT->Group[0].PINCFG[24].reg = PORT_PINCFG_PMUXEN;
    PORT->Group[0].PINCFG[25].reg = PORT_PINCFG_PMUXEN;
    // PMUX[12] covers PA24 (even = PMUXE) and PA25 (odd = PMUXO); function G (USB) = 6
    PORT->Group[0].PMUX[12].reg = PORT_PMUX_PMUXE(6) | PORT_PMUX_PMUXO(6);

    // Enable USB clocks: APBB (register access) + AHB (DMA/data transfers)
    PM->APBBMASK.reg |= PM_APBBMASK_USB;
    PM->AHBMASK.reg  |= PM_AHBMASK_USB;
    // Route GCLK0 (48 MHz DFLL) to the USB peripheral
    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN |
                        GCLK_CLKCTRL_GEN_GCLK0 |
                        GCLK_CLKCTRL_ID(USB_GCLK_ID);
    while (GCLK->STATUS.bit.SYNCBUSY);

    tusb_init();
}

void cdc_task(void) {
    tud_task();
}

bool cdc_is_connected(void) {
    return tud_cdc_connected();
}

uint32_t cdc_write(const uint8_t *buf, uint32_t len) {
    return (uint32_t)tud_cdc_write(buf, len);
}

void cdc_flush(void) {
    tud_cdc_write_flush();
}
