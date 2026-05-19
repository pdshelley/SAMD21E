/*
 * spi0_gclk.c — SERCOM0 generic-clock bring-up.
 *
 * Gates the two clocks that SERCOM0 needs before any of its registers
 * can be touched from Swift:
 *
 *   1. APBC.SERCOM0   — bus clock that lets the CPU read/write SERCOM0
 *                       registers at all. Without this, every access
 *                       returns 0xFFFFFFFF and raises a bus fault that
 *                       traps in HardFault.
 *   2. GCLK0 → CORE   — peripheral core clock. SCK is derived from
 *                       this; without it, SWRST never completes and
 *                       every transmit hangs in SYNCBUSY.
 *   3. GCLK0 → SLOW   — slow-domain clock used internally by the
 *                       SERCOM for SYNCBUSY synchronization. Required
 *                       even though we don't expose any slow-domain
 *                       feature.
 *
 * Why C, not Swift: the CMSIS device headers (`sam.h`) provide the
 * GCLK / PM register definitions and bit macros for free, and the
 * existing `cdc_init` (USB bring-up) uses the same pattern. Keeping
 * GCLK programming on the C side avoids re-translating those macros
 * into the Swift bitfield HAL just for two boilerplate writes that
 * happen exactly once at boot.
 *
 * GCLK0 is the chip's main system clock generator. On the QT Py
 * SAMD21 the bootloader leaves GCLK0 running at ~24 MHz (the part is
 * nominally 48 MHz; the empirical 24 MHz determines the SCK numbers
 * in `SPI0.ClockRateSelect`).
 *
 * Called once from the staged `SPI0.configure()`. Idempotent — the
 * GCLK CLKCTRL writes are full-word and the APBCMASK write is a
 * read-modify-write, so re-entering this function is safe.
 */

#include <sam.h>

void spi0_enable_generic_clocks(void) {
    /* APB clock for SERCOM0 register access. */
    PM->APBCMASK.reg |= PM_APBCMASK_SERCOM0; // TODO: Should be able to use PowerManager.swift

    /* Route GCLK0 to the SERCOM0 core clock. CLKCTRL is single-write
     * (SELECT-then-write is implicit in the encoding) and synchronizes
     * across the GCLK domain — wait for SYNCBUSY before continuing or
     * the SLOW write below races. */
    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | // TODO: Should be able to use GenericClockController.swift
                        GCLK_CLKCTRL_ID_SERCOM0_CORE;
    while (GCLK->STATUS.bit.SYNCBUSY) {
    }

    /* Route GCLK0 to the shared SERCOM slow clock. ID_SERCOMX_SLOW is
     * the same generator slot for every SERCOM — programming it here
     * is harmless if another SERCOM (e.g. USB CDC's SERCOM) has
     * already done it. */
    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | // TODO: Should be able to use GenericClockController.swift
                        GCLK_CLKCTRL_ID_SERCOMX_SLOW;
    while (GCLK->STATUS.bit.SYNCBUSY) {
    }
}
