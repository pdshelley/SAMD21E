// Linker/runtime symbols required by Embedded Swift on Cortex-M0+.

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

uintptr_t __stack_chk_guard = 0xDEADBEEF;

void arc4random_buf(void *buf, size_t nbytes) {
    unsigned char *b = (unsigned char *)buf;
    for (size_t i = 0; i < nbytes; i++) {
        b[i] = 0xA5;
    }
}

void __stack_chk_fail(void) {
    for (;;)
        ;
}

uint32_t _volatileRegisterReadUInt32(uintptr_t address) {
    return *(volatile uint32_t *)address;
}

void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value) {
    *(volatile uint32_t *)address = value;
}

int posix_memalign(void **memptr, size_t alignment, size_t size) {
    (void)memptr;
    (void)alignment;
    (void)size;
    __builtin_trap();
}

uint32_t __atomic_load_4(const volatile void *ptr, int order) {
    (void)order;
    return *(const volatile uint32_t *)ptr;
}

void __atomic_store_4(volatile void *ptr, uint32_t val, int order) {
    (void)order;
    *(volatile uint32_t *)ptr = val;
}

uint32_t __atomic_fetch_add_4(volatile void *ptr, uint32_t val, int order) {
    (void)order;
    volatile uint32_t *p = (volatile uint32_t *)ptr;
    uint32_t old = *p;
    *p = old + val;
    return old;
}

uint32_t __atomic_fetch_sub_4(volatile void *ptr, uint32_t val, int order) {
    (void)order;
    volatile uint32_t *p = (volatile uint32_t *)ptr;
    uint32_t old = *p;
    *p = old - val;
    return old;
}

bool __atomic_compare_exchange_4(volatile void *ptr, void *expected, uint32_t desired,
                                 bool weak, int success, int failure) {
    (void)weak;
    (void)success;
    (void)failure;
    volatile uint32_t *p = (volatile uint32_t *)ptr;
    uint32_t *exp = (uint32_t *)expected;
    if (*p == *exp) {
        *p = desired;
        return true;
    }
    *exp = *p;
    return false;
}
