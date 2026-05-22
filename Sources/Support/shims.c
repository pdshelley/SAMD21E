#include "BridgingHeader.h"
#include <stddef.h>
#include <stdint.h>

uintptr_t __stack_chk_guard = 0xDEADBEEF;

void arc4random_buf(void *buf, size_t nbytes) {
    unsigned char *b = (unsigned char *)buf;
    for (size_t i = 0; i < nbytes; i++) b[i] = 0xA5;
}

uint32_t _volatileRegisterReadUInt32(uintptr_t address) {
    return *(volatile uint32_t *)address;
}

void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value) {
    *(volatile uint32_t *)address = value;
}
