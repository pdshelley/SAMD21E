//
//  BridgingHeader.h
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

#pragma once
#include <stdint.h>
#include <stdbool.h>

/// Millisecond delay backed by SysTick (delay.c)
extern void delay(unsigned long ms);

/// Returns the number of milliseconds elapsed since startup, backed by SysTick (delay.c).
/// Overflows approximately every 49 days.
extern unsigned long millis(void);

/// Sub-microsecond busy wait (delay.c / delay.h).
extern void delay_busy_microseconds(unsigned int usec);

/// Volatile Register Read
///
/// At some point in the future this might be added to Swift, if so this should
/// be removed in favor of a Swift only approach.
extern uint32_t _volatileRegisterReadUInt32(uintptr_t address);
extern uint16_t _volatileRegisterReadUInt16(uintptr_t address);

/// Volatile Register Read
///
/// At some point in the future this might be added to Swift, if so this should
/// be removed in favor of a Swift only approach.
extern void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value);
extern void _volatileRegisterWriteUInt16(uintptr_t address, uint16_t value);

/// Enable GCLK0 on SERCOM0 core + SERCOM slow (see spi0_gclk.c).
extern void spi0_enable_generic_clocks(void); // TODO: Switch to the Swift versions so this can be removed.

/// Enable GCLK0 on SERCOM1 core + SERCOM slow (see spi1_gclk.c).
extern void spi1_enable_generic_clocks(void);

extern bool user_row_write_mac_c(
    uint8_t b0,
    uint8_t b1,
    uint8_t b2,
    uint8_t b3,
    uint8_t b4,
    uint8_t b5
);

#include "cdc_bridge.h"
