/*
 * app_main.c — Production firmware (pure C, same model as make bringup).
 *
 * No Embedded Swift runtime or SERCOM HAL in the main loop — that path caused
 * HardFaults when SPI1/DMAC were configured from Swift on CDC connect.
 *
 * SERCOM3 I2C + APDS run in i2c3_master.c. NeoPixel (SERCOM1) will be added in C
 * next; until then the RGB values are printed on CDC.
 */

#include "cdc_bridge.h"
#include <sam.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

extern void i2c3_poll(unsigned long ms);
extern bool i2c3_staged_bringup_done(void);
extern bool i2c3_apds_sensor_ready(void);
extern bool i2c3_apds_read_rgb(uint8_t *r, uint8_t *g, uint8_t *b);
extern uint8_t i2c3_read_fail_step(void);
extern unsigned long millis(void);

#define PORTA_DIRSET (0x41004400u + 0x08u)
#define PORTA_OUTCLR (0x41004400u + 0x14u)
#define PORTA_OUTTGL (0x41004400u + 0x1Cu)
#define PA02_MASK (1u << 2u)

#define COLOR_INTERVAL_MS 200u
#define STATUS_INTERVAL_MS 3000u
enum {
    SNS_WAIT = 0,
    SNS_RUNNING,
};

static void cdc_puts(const char *s) {
    const char *p = s;
    while (*p) {
        p++;
    }
    if (p > s && cdc_is_connected()) {
        cdc_write((const uint8_t *)s, (uint32_t)(p - s));
        cdc_flush();
        cdc_task();
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
static unsigned long last_color_ms;
static unsigned long last_status_ms;
static uint8_t sensor_stage;
static bool usb_was_connected;

static void sensor_poll(unsigned long ms) {
    if (!i2c3_staged_bringup_done()) {
        return;
    }

    switch (sensor_stage) {
    case SNS_WAIT:
        if (i2c3_apds_sensor_ready()) {
            cdc_puts("Color loop (CDC RGB; NeoPixel C driver next)\r\n");
            last_color_ms = ms;
            last_status_ms = ms;
            sensor_stage = SNS_RUNNING;
        } else {
            cdc_puts("APDS-9999 not enabled (see isolate log)\r\n");
            sensor_stage = SNS_RUNNING;
        }
        break;

    case SNS_RUNNING:
        if ((ms - last_color_ms) >= COLOR_INTERVAL_MS) {
            uint8_t r = 0;
            uint8_t g = 0;
            uint8_t b = 0;
            last_color_ms = ms;
            (void)i2c3_apds_read_rgb(&r, &g, &b);
            /* NeoPixel update will go here (spi1_neopixel.c). */
        }
        if ((ms - last_status_ms) >= STATUS_INTERVAL_MS) {
            uint8_t r = 0;
            uint8_t g = 0;
            uint8_t b = 0;
            char line[40];
            last_status_ms = ms;
            if (i2c3_apds_read_rgb(&r, &g, &b)) {
                snprintf(line, sizeof(line), "RGB %02X %02X %02X\r\n", r, g, b);
                cdc_puts(line);
            } else {
                snprintf(line, sizeof(line), "RGB read failed (rd %u)\r\n",
                         (unsigned)i2c3_read_fail_step());
                cdc_puts(line);
            }
        }
        break;

    default:
        sensor_stage = SNS_WAIT;
        break;
    }
}

void app_init(void) {
    led_init();
    cdc_init();
    last_blink_ms = millis();
    last_color_ms = 0;
    last_status_ms = 0;
    sensor_stage = SNS_WAIT;
    usb_was_connected = false;
}

void app_main(void) {
    unsigned long ms = millis();

    cdc_task();
    i2c3_poll(ms);

    bool connected = cdc_is_connected();
    if (connected && !usb_was_connected) {
        cdc_puts("USB connected\r\n");
    }
    usb_was_connected = connected;

    if (connected) {
        sensor_poll(ms);
    } else {
        sensor_stage = SNS_WAIT;
    }

    if ((ms - last_blink_ms) >= 1000u) {
        led_toggle();
        last_blink_ms = ms;
    }
}
