/*
 * i2c3_gclk.c — SERCOM3 generic-clock bring-up (QT Py STEMMA QT I2C).
 *
 * PA16/PA17 are muxed to SERCOM3 PAD0/1 (function D) so SERCOM1 stays free
 * for NeoPixel SPI on PA18. Adafruit Arduino Wire uses SERCOM1 on the same
 * pins; we intentionally use SERCOM3 for concurrent SPI + I2C.
 */

#include <sam.h>

void i2c3_enable_generic_clocks(void) {
    PM->APBBMASK.reg |= PM_APBBMASK_PORT;
    PM->APBCMASK.reg |= PM_APBCMASK_SERCOM3;

    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 |
                        GCLK_CLKCTRL_ID_SERCOM3_CORE;
    while (GCLK->STATUS.bit.SYNCBUSY) {
    }

    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 |
                        GCLK_CLKCTRL_ID_SERCOMX_SLOW;
    while (GCLK->STATUS.bit.SYNCBUSY) {
    }
}
