//
//  BridgingHeader.h
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

#pragma once
#include <stdint.h>

/// Millisecond delay backed by SysTick (delay.c)
extern void delay(unsigned long ms);

/// Returns the number of milliseconds elapsed since startup, backed by SysTick (delay.c).
/// Overflows approximately every 49 days.
extern unsigned long millis(void);

/// Volatile Register Read
///
/// At some point in the future this might be added to Swift, if so this should
/// be removed in favor of a Swift only approach.
extern uint32_t _volatileRegisterReadUInt32(uintptr_t address);

/// Volatile Register Read
///
/// At some point in the future this might be added to Swift, if so this should
/// be removed in favor of a Swift only approach.
extern void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value);

#include "cdc_bridge.h"
