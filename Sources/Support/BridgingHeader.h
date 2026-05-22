#pragma once
#include <stdint.h>

extern uint32_t _volatileRegisterReadUInt32(uintptr_t address);
extern void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value);
