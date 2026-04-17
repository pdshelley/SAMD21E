#include "delay.h"
#include <stdint.h>

/*
 * Blink PA02 at 1-second intervals using direct memory-mapped I/O.
 *
 * PORT Group A base address: 0x41004400  (SAMD21 datasheet §23.8)
 *
 *   DIRSET  +0x08  write a 1 to make the corresponding pin an output
 *   OUTCLR  +0x14  write a 1 to drive the corresponding pin low
 *   OUTSET  +0x18  write a 1 to drive the corresponding pin high
 *
 * PA02 is bit 2, so the mask is (1u << 2) = 0x00000004.
 */

#define PORTA_DIRSET (*(volatile uint32_t *)0x41004408)
#define PORTA_OUTCLR (*(volatile uint32_t *)0x41004414)
#define PORTA_OUTSET (*(volatile uint32_t *)0x41004418)

#define PA02 (1u << 2)

void app_init(void) {
    PORTA_DIRSET = PA02; /* configure PA02 as an output */
    PORTA_OUTCLR = PA02; /* start low */
}

void app_main(void) {
    PORTA_OUTSET = PA02;
    delay(1000); /* high for 1000 ms */
    PORTA_OUTCLR = PA02;
    delay(1000); /* low  for 1000 ms */
}
