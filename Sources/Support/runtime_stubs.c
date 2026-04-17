#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/*
 * Heap allocation is not available on bare metal. Trap immediately if the
 * Embedded Swift runtime ever tries to allocate — this should never happen
 * with value-type-only Swift code, but the symbol must be defined to link.
 */
int posix_memalign(void **memptr, size_t alignment, size_t size) {
    (void)memptr; (void)alignment; (void)size;
    __builtin_trap();
}

/*
 * Cortex-M0+ has no hardware atomic instructions; LLVM lowers all C11/Swift
 * atomic operations to calls into libatomic. These stubs are correct for
 * single-threaded bare-metal code where no preemption occurs.
 */

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

bool __atomic_compare_exchange_4(volatile void *ptr, void *expected,
                                  uint32_t desired, bool weak,
                                  int success, int failure) {
    (void)weak; (void)success; (void)failure;
    volatile uint32_t *p = (volatile uint32_t *)ptr;
    uint32_t *exp = (uint32_t *)expected;
    if (*p == *exp) {
        *p = desired;
        return true;
    }
    *exp = *p;
    return false;
}
