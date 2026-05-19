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

#ifndef _DELAY_
#define _DELAY_

#include <stdint.h>

extern unsigned long millis(void);
extern unsigned long micros(void);
extern void delay(unsigned long ms);
extern void systick_init(void);

/// Busy wait (asm loop). Safe against LLVM optimizing away unlike a Swift `for` loop.
extern void delay_busy_microseconds(unsigned int usec);

/*
 * Busy-wait for the given number of microseconds.
 * Loop runs at 3 cycles/iteration on Cortex-M0+ (sub, bne).
 * VARIANT_MCK / 1000000 / 3 == iterations per µs at 48 MHz == 16.
 */
static __inline__ void delayMicroseconds(unsigned int usec)
    __attribute__((always_inline, unused));

static __inline__ void delayMicroseconds(unsigned int usec) {
    if (usec == 0)
        return;

    uint32_t n = usec * (F_CPU / 1000000) / 3;

    __asm__ __volatile__("1:              \n"
                         "   sub %0, #1   \n"
                         "   bne 1b       \n"
                         : "+r"(n));
}

#endif /* _DELAY_ */
