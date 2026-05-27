/*
 * app_bringup.c — Pure-C firmware for I2C / USB isolation (no Swift linked).
 *
 * Build: make bringup
 *
 * Proves SERCOM3 I2C on PA16/PA17 without Swift HAL or Embedded Swift runtime.
 */

#include "cdc_bridge.h"
#include <sam.h>
#include <stdbool.h>
#include <stdint.h>

extern void i2c3_poll(unsigned long ms);
extern unsigned long millis(void);

#define PORTA_DIRSET (0x41004400u + 0x08u)
#define PORTA_OUTCLR (0x41004400u + 0x14u)
#define PORTA_OUTTGL (0x41004400u + 0x1Cu)
#define PA02_MASK (1u << 2u)

static void cdc_puts(const char *s) {
    const char *p = s;
    while (*p) {
        p++;
    }
    if (p > s && cdc_is_connected()) {
        cdc_write((const uint8_t *)s, (uint32_t)(p - s));
        cdc_flush();
    }
}

static void led_init(void) {
    *(volatile uint32_t *)PORTA_DIRSET = PA02_MASK;
    *(volatile uint32_t *)PORTA_OUTCLR = PA02_MASK;
}

static void led_toggle(void) {
    *(volatile uint32_t *)PORTA_OUTTGL = PA02_MASK;
}

static unsigned long last_blink_ms;
static bool usb_was_connected;

void app_init(void) {
    led_init();
    cdc_init();
    last_blink_ms = millis();
    usb_was_connected = false;
}

void app_main(void) {
    unsigned long ms = millis();

    cdc_task();
    i2c3_poll(ms);

    bool connected = cdc_is_connected();
    if (connected && !usb_was_connected) {
        cdc_puts("USB connected (bringup C)\r\n");
    }
    usb_was_connected = connected;

    if ((ms - last_blink_ms) >= 1000u) {
        led_toggle();
        last_blink_ms = ms;
    }
}
