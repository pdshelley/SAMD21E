/*
 * spi1_gclk.c — SERCOM1 generic-clock bring-up (QT Py NeoPixel on PA18).
 *
 * Same pattern as spi0_gclk.c; see that file for rationale.
 */

#include <sam.h>

void spi1_enable_generic_clocks(void) {
    PM->APBBMASK.reg |= PM_APBBMASK_PORT;
    PM->APBCMASK.reg |= PM_APBCMASK_SERCOM1;

    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 |
                        GCLK_CLKCTRL_ID_SERCOM1_CORE;
    while (GCLK->STATUS.bit.SYNCBUSY) {
    }

    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 |
                        GCLK_CLKCTRL_ID_SERCOMX_SLOW;
    while (GCLK->STATUS.bit.SYNCBUSY) {
    }
}
