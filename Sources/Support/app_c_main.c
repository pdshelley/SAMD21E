/*
 * app_c_main.c — Hybrid firmware main loop (make / make all).
 *
 * I2C/APDS, NeoPixel SPI/DMAC, CDC, and status LED are all CMSIS C.
 * ApplicationBridge.swift only forwards app_init / app_main here.
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
extern bool spi1_neopixel_init(void);
extern void spi1_neopixel_set_rgb(uint8_t red, uint8_t green, uint8_t blue);
extern void cdc_init(void);

#define PA02_MASK (1u << 2u)
#define BLINK_INTERVAL_MS 1000u
#define COLOR_INTERVAL_MS 200u
#define STATUS_INTERVAL_MS 3000u

enum {
    SNS_WAIT = 0,
    SNS_RUNNING,
};

static uint8_t sensor_stage;
static bool usb_was_connected;
static bool neo_inited;
static bool led_on;
static unsigned long last_blink_ms;
static unsigned long last_color_ms;
static unsigned long last_status_ms;

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

static void status_led_set(bool on) {
    if (on) {
        PORT->Group[0].OUTSET.reg = PA02_MASK;
    } else {
        PORT->Group[0].OUTCLR.reg = PA02_MASK;
    }
    led_on = on;
}

static void color_poll(unsigned long ms) {
    uint8_t r = 0;
    uint8_t g = 0;
    uint8_t b = 0;

    if (!neo_inited || !i2c3_apds_sensor_ready()) {
        return;
    }

    if ((ms - last_color_ms) < COLOR_INTERVAL_MS) {
        return;
    }
    last_color_ms = ms;

    if (!i2c3_apds_read_rgb(&r, &g, &b)) {
        return;
    }
    spi1_neopixel_set_rgb(r, g, b);
}

static void status_poll(unsigned long ms) {
    uint8_t r = 0;
    uint8_t g = 0;
    uint8_t b = 0;
    char line[48];

    if (!i2c3_apds_sensor_ready()) {
        return;
    }

    if ((ms - last_status_ms) < STATUS_INTERVAL_MS) {
        return;
    }
    last_status_ms = ms;

    if (i2c3_apds_read_rgb(&r, &g, &b)) {
        snprintf(line, sizeof(line), "RGB %02X %02X %02X\r\n", r, g, b);
    } else {
        snprintf(line, sizeof(line), "RGB read failed (rd %u)\r\n",
                 (unsigned)i2c3_read_fail_step());
    }
    cdc_puts(line);
}

static void sensor_poll(unsigned long ms) {
    if (!i2c3_staged_bringup_done()) {
        return;
    }

    switch (sensor_stage) {
    case SNS_WAIT:
        if (i2c3_apds_sensor_ready()) {
            cdc_puts("Color loop (C I2C + C NeoPixel DMA)\r\n");
            last_color_ms = ms;
            last_status_ms = ms;
            sensor_stage = SNS_RUNNING;
        } else {
            cdc_puts("APDS-9999 not enabled (see isolate log)\r\n");
            sensor_stage = SNS_RUNNING;
        }
        break;

    case SNS_RUNNING:
        if (!neo_inited) {
            if (spi1_neopixel_init()) {
                neo_inited = true;
                cdc_puts("NeoPixel SPI+DMAC ready\r\n");
            }
        }
        if (neo_inited) {
            color_poll(ms);
            status_poll(ms);
        }
        break;

    default:
        sensor_stage = SNS_WAIT;
        break;
    }
}

void app_c_main_poll(unsigned long ms) {
    bool connected = cdc_is_connected();

    cdc_task();
    i2c3_poll(ms);

    if (connected && !usb_was_connected) {
        cdc_puts("USB connected\r\n");
    }
    usb_was_connected = connected;

    if (connected) {
        sensor_poll(ms);
    } else {
        sensor_stage = SNS_WAIT;
        neo_inited = false;
    }

    if ((ms - last_blink_ms) >= BLINK_INTERVAL_MS) {
        last_blink_ms = ms;
        status_led_set(!led_on);
    }
}

bool app_c_may_configure_spi(void) {
    return neo_inited;
}

bool app_c_color_loop_active(void) {
    return sensor_stage == SNS_RUNNING && i2c3_apds_sensor_ready();
}

void app_c_notify_spi_ready(void) {
}

bool app_c_apds_read_rgb(uint8_t *r, uint8_t *g, uint8_t *b) {
    return i2c3_apds_read_rgb(r, g, b);
}

void app_c_platform_init(void) {
    PM->APBBMASK.reg |= PM_APBBMASK_PORT;
    PORT->Group[0].DIRSET.reg = PA02_MASK;
    PORT->Group[0].OUTCLR.reg = PA02_MASK;
    led_on = false;
    last_blink_ms = millis();
    last_color_ms = 0;
    last_status_ms = 0;
    sensor_stage = SNS_WAIT;
    usb_was_connected = false;
    neo_inited = false;
    cdc_init();
}

void app_c_status_led_toggle(bool on) {
    status_led_set(on);
}
