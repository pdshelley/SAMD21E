/*
 * dmac_gclk.c — DMAC bus clocks (CMSIS only; avoid Swift PM during SPI bring-up).
 */

#include <sam.h>

void dmac_enable_clocks(void) {
    PM->AHBMASK.reg |= PM_AHBMASK_DMAC;
    PM->APBBMASK.reg |= PM_APBBMASK_DMAC;
}
