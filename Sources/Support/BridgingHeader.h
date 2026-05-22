//
//  BridgingHeader.h
//  SAMD21E
//

#pragma once
#include <stdint.h>

extern unsigned long millis(void);

extern uint32_t _volatileRegisterReadUInt32(uintptr_t address);
extern void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value);
