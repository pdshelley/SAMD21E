#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

uintptr_t __stack_chk_guard = 0xDEADBEEF;

void arc4random_buf(void *buf, size_t n) {
    for (size_t i = 0; i < n; i++) ((unsigned char *)buf)[i] = 0xA5;
}

void __stack_chk_fail(void) { for (;;); }

uint32_t _volatileRegisterReadUInt32(uintptr_t a) { return *(volatile uint32_t *)a; }
void _volatileRegisterWriteUInt32(uintptr_t a, uint32_t v) { *(volatile uint32_t *)a = v; }

int posix_memalign(void **p, size_t a, size_t s) {
    (void)p; (void)a; (void)s;
    __builtin_trap();
}

uint32_t __atomic_load_4(const volatile void *p, int o) {
    (void)o; return *(const volatile uint32_t *)p;
}
void __atomic_store_4(volatile void *p, uint32_t v, int o) {
    (void)o; *(volatile uint32_t *)p = v;
}
uint32_t __atomic_fetch_add_4(volatile void *p, uint32_t v, int o) {
    (void)o; volatile uint32_t *q = p; uint32_t old = *q; *q = old + v; return old;
}
uint32_t __atomic_fetch_sub_4(volatile void *p, uint32_t v, int o) {
    (void)o; volatile uint32_t *q = p; uint32_t old = *q; *q = old - v; return old;
}
bool __atomic_compare_exchange_4(volatile void *p, void *e, uint32_t d,
                                 bool w, int s, int f) {
    (void)w; (void)s; (void)f;
    volatile uint32_t *q = p; uint32_t *x = e;
    if (*q == *x) { *q = d; return true; }
    *x = *q; return false;
}
