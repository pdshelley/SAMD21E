/*
  Original work:
    Copyright (c) 2015 Arduino LLC. All rights reserved.
    SAMD51 support added by Adafruit - Copyright (c) 2018 Dean Miller for Adafruit Industries

  This file is a heavily modified version, simplified for SAMD21 (Cortex-M0+) only and adapted for the Embedded Swift example.

  Modifications:
    Copyright (c) 2026 Swift4Arduino. All rights reserved.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "delay.h"
#include <sam.h>

/*
 * System Core Clock is at 1MHz (8MHz/8) at Reset.
 * It is switched to 48MHz in the Reset Handler (startup.c).
 */
uint32_t SystemCoreClock = 1000000ul;

/*
 * Start the 1ms SysTick used by millis() / micros() / delay().
 */
void systick_init(void) {
    if (SysTick_Config(SystemCoreClock / 1000)) {
        while (1)
            ;
    }
    NVIC_SetPriority(SysTick_IRQn, (1 << __NVIC_PRIO_BITS) - 2);
}

/** Tick counter (ms) incremented by SysTick_Handler each millisecond */
static volatile uint32_t _ulTickCount = 0;

unsigned long millis(void) { return _ulTickCount; }

unsigned long micros(void) {
    uint32_t ticks, ticks2;
    uint32_t pend, pend2;
    uint32_t count, count2;

    ticks2 = SysTick->VAL;
    pend2 = !!(SCB->ICSR & SCB_ICSR_PENDSTSET_Msk);
    count2 = _ulTickCount;

    do {
        ticks = ticks2;
        pend = pend2;
        count = count2;
        ticks2 = SysTick->VAL;
        pend2 = !!(SCB->ICSR & SCB_ICSR_PENDSTSET_Msk);
        count2 = _ulTickCount;
    } while ((pend != pend2) || (count != count2) || (ticks < ticks2));

    return ((count + pend) * 1000) +
           (((SysTick->LOAD - ticks) * (1048576 / (F_CPU / 1000000))) >> 20);
}

void delay(unsigned long ms) {
    if (ms == 0)
        return;

    uint32_t start = micros();

    while (ms > 0) {
        while (ms > 0 && (micros() - start) >= 1000) {
            ms--;
            start += 1000;
        }
    }
}

void SysTick_DefaultHandler(void) { _ulTickCount++; }

void delay_busy_microseconds(unsigned int usec) {
    if (usec == 0)
        return;

    /*
     * Volatile spin: not a candidate for LLVM dead-store elimination, unlike a plain
     * Swift `var` loop in Embedded. Tuned roughly for ~48 MHz M0+ (project F_CPU).
     * Count with uncertainty ±30% — use a LA, not this, for exact µs metrology.
     */
    uint32_t n = (uint32_t)usec * (F_CPU / 1000000u) * 6u;
    if (n < 1u)
        n = 1u;
    volatile uint32_t scratch = n;
    while (scratch != 0) {
        scratch -= 1;
    }
}
