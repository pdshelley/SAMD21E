/*
 * fault_diag.c — bare-metal fault beacons on PA02 (QT Py NeoPixel / status LED pin).
 *
 * Temporary bring-up aid: distinguish stack-smash detection from HardFault without
 * a debugger. Uses only direct PORTA writes (no Swift, no TinyUSB).
 *
 * Logic analyzer on PA02:
 *   __stack_chk_fail: 2 short positive pulses, long gap, repeat.
 *   HardFault_Handler: 5 short positive pulses, long gap, repeat.
 *
 * Remove or simplify after the SPI configure issue is understood.
 */

#include <stdint.h>

/* SAMD21 PORT A — same base as Sources/SAMD21/module/GPIO.swift */
#define PORTA_BASE UINT32_C(0x41004400)
#define PORTA_DIRSET (PORTA_BASE + 0x08u)
#define PORTA_OUTSET (PORTA_BASE + 0x18u)
#define PORTA_OUTCLR (PORTA_BASE + 0x14u)

/* QT Py “status” LED is PA02 in this project (see Application.swift / appInit). */
#define PA02_MASK UINT32_C(1u << 2)

static void diag_spin(volatile uint32_t iterations) {
    for (volatile uint32_t i = 0; i < iterations; i++) {
    }
}

static void diag_pa02_output_high_drive(void) {
    *(volatile uint32_t *)PORTA_DIRSET = PA02_MASK;
}

static void diag_pulse_once(void) {
    *(volatile uint32_t *)PORTA_OUTSET = PA02_MASK;
    diag_spin(60000u);
    *(volatile uint32_t *)PORTA_OUTCLR = PA02_MASK;
    diag_spin(60000u);
}

void __stack_chk_fail(void) {
    diag_pa02_output_high_drive();
    for (;;) {
        diag_pulse_once();
        diag_pulse_once();
        diag_spin(400000u);
    }
}

void HardFault_Handler(void) {
    diag_pa02_output_high_drive();
    for (;;) {
        for (unsigned n = 0; n < 5u; n++) {
            diag_pulse_once();
        }
        diag_spin(400000u);
    }
}
