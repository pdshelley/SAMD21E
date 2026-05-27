/*
 * app_c_main.c — C-side main-loop hooks (CDC text, I2C schedule).
 *
 * Keep USB connect handling and I2C polling out of Swift to avoid stack /
 * runtime issues when the host opens the serial port.
 */

#include "cdc_bridge.h"
#include <stdbool.h>

extern void i2c3_poll(unsigned long ms);

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

static bool usb_was_connected;

void app_c_main_poll(unsigned long ms) {
    i2c3_poll(ms);

    bool connected = cdc_is_connected();
    if (connected && !usb_was_connected) {
        cdc_puts("USB connected\r\n");
    }
    usb_was_connected = connected;
}
