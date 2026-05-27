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
#define COLOR_INTERVAL_MS 220u /* match ~200 ms LS_MEAS_RATE in i2c3_apds_enable */
#define STATUS_INTERVAL_MS 3000u

/* Software white balance (×64). */
#define WB_R_NUM 40u
#define WB_G_NUM 72u
#define WB_B_NUM 96u

/* Cyan LED target (~#00AEEF): G:B ratio for blue-dominant sensor readings */
#define CYAN_REF_G 174u
#define CYAN_REF_B 239u

/* max must exceed second by this % before full LED saturation (else softer / held) */
#define HUE_DOMINANCE_PCT 140u
#define HUE_SOFT_PEAK 200u
#define NEO_RED_CAP_BLUE 36u
#define NEO_GREEN_CAP_RED 40u
#define NEO_BLUE_CAP_RED 32u

/* Frames to accept a new color (demo: switch swatches without long fade) */
#define CLASS_LOCK_FRAMES 2u

enum {
    SNS_WAIT = 0,
    SNS_RUNNING,
};

enum neo_color_class {
    NEO_CLS_GENERIC = 0,
    NEO_CLS_YELLOW,
    NEO_CLS_BLUE,
    NEO_CLS_RED,
};

static uint8_t sensor_stage;
static bool usb_was_connected;
static bool neo_inited;
static bool led_on;
static bool last_rgb_valid;
static uint8_t last_r;
static uint8_t last_g;
static uint8_t last_b;
static uint8_t last_neo_r;
static uint8_t last_neo_g;
static uint8_t last_neo_b;
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

static uint8_t gamma2(uint8_t v) {
    return (uint8_t)(((uint16_t)v * (uint16_t)v + 127u) / 255u);
}

static uint8_t wb_scale(uint8_t v, uint8_t num) {
    uint16_t x = (uint16_t)v * (uint16_t)num;
    if (x > 16320u) {
        return 255u;
    }
    return (uint8_t)(x / 64u);
}

static uint8_t sensor_max2(uint8_t a, uint8_t b) {
    return a > b ? a : b;
}

/*
 * Demo classifier: blue = low R and/or B at top with R well below G; yellow = R≈G;
 * red = R > G. Order matters so yellow/red are not forced to blue by high B alone.
 */
static bool sensor_blue_clear(uint8_t sr, uint8_t sg, uint8_t sb) {
    return sr < 0x50u && sb >= 0x58u && sb + 12u >= sg;
}

static bool sensor_blue_b_wins(uint8_t sr, uint8_t sg, uint8_t sb) {
    uint8_t hi;

    if (sb < 0x60u) {
        return false;
    }
    hi = sensor_max2(sr, sg);
    if (sb + 14u < hi) {
        return false;
    }
    if (sb < sr + 14u) {
        return false;
    }
    /* Blue card: red channel clearly below green */
    return sr + 14u < sg || sr < 0x58u;
}

static bool sensor_red_dominant(uint8_t sr, uint8_t sg, uint8_t sb) {
    (void)sb;
    return sr >= 0x44u && sr > sg + 4u;
}

static bool sensor_yellow_dominant(uint8_t sr, uint8_t sg, uint8_t sb) {
    (void)sb;
    if (sr < 0x44u || sg < 0x48u) {
        return false;
    }
    if (sr > sg + 4u) {
        return false;
    }
    return sg + 8u >= sr && sr + 18u >= sg;
}

static enum neo_color_class sensor_classify_instant(uint8_t sr, uint8_t sg, uint8_t sb) {
    if (sensor_blue_clear(sr, sg, sb)) {
        return NEO_CLS_BLUE;
    }
    if (sensor_red_dominant(sr, sg, sb)) {
        return NEO_CLS_RED;
    }
    if (sensor_yellow_dominant(sr, sg, sb)) {
        return NEO_CLS_YELLOW;
    }
    if (sensor_blue_b_wins(sr, sg, sb)) {
        return NEO_CLS_BLUE;
    }
    return NEO_CLS_GENERIC;
}

static enum neo_color_class sensor_classify_locked(uint8_t sr, uint8_t sg, uint8_t sb) {
    static enum neo_color_class locked = NEO_CLS_GENERIC;
    static enum neo_color_class pending = NEO_CLS_GENERIC;
    static uint8_t pending_count;
    enum neo_color_class inst;

    inst = sensor_classify_instant(sr, sg, sb);
    if (inst == locked) {
        pending = locked;
        pending_count = 0;
        return locked;
    }
    if (inst == pending) {
        if (pending_count < 255u) {
            pending_count++;
        }
        if (pending_count >= CLASS_LOCK_FRAMES) {
            locked = inst;
            pending_count = 0;
        }
    } else {
        pending = inst;
        pending_count = 1u;
    }
    return locked;
}

static void neo_hold_blend(uint8_t *nr, uint8_t *ng, uint8_t *nb, enum neo_color_class cls,
                           uint16_t ratio_pct) {
    static uint8_t hold_r;
    static uint8_t hold_g;
    static uint8_t hold_b;
    static bool hold_init;
    static enum neo_color_class hold_cls;

    if (cls != hold_cls) {
        hold_init = false;
        hold_cls = cls;
    }
    if (cls != NEO_CLS_GENERIC) {
        ratio_pct = 200u;
    }

    if (!hold_init) {
        hold_r = *nr;
        hold_g = *ng;
        hold_b = *nb;
        hold_init = true;
    } else if (ratio_pct < HUE_DOMINANCE_PCT) {
        *nr = (uint8_t)(((uint16_t)hold_r * 3u + (uint16_t)*nr) / 4u);
        *ng = (uint8_t)(((uint16_t)hold_g * 3u + (uint16_t)*ng) / 4u);
        *nb = (uint8_t)(((uint16_t)hold_b * 3u + (uint16_t)*nb) / 4u);
    } else {
        *nr = (uint8_t)(((uint16_t)hold_r + (uint16_t)*nr) / 2u);
        *ng = (uint8_t)(((uint16_t)hold_g + (uint16_t)*ng) / 2u);
        *nb = (uint8_t)(((uint16_t)hold_b + (uint16_t)*nb) / 2u);
    }

    hold_r = *nr;
    hold_g = *ng;
    hold_b = *nb;
}

/*
 * APDS "blue" still has significant R/G vs human cyan. Scale G:B toward 174:239 and
 * cap R so the LED reads cyan (~#00AEEF), not lavender (high R + B, weak G).
 */
static void neo_from_blue_cyan(uint8_t sr, uint8_t sg, uint8_t sb, uint8_t *nr, uint8_t *ng,
                               uint8_t *nb) {
    uint16_t bb;
    uint16_t g16;
    uint16_t r16;
    uint16_t peak;

    bb = sb;
    if (bb < 16u) {
        *nr = 0;
        *ng = 0;
        *nb = 0;
        return;
    }

    /* Fixed cyan hue (G:B = 174:239); brightness follows blue channel level */
    peak = (uint16_t)bb * 255u / 200u;
    if (peak > 255u) {
        peak = 255u;
    }

    g16 = (uint16_t)CYAN_REF_G * peak / CYAN_REF_B;
    if (g16 > 255u) {
        g16 = 255u;
    }

    r16 = (uint16_t)sr * peak / bb;
    if (r16 > NEO_RED_CAP_BLUE) {
        r16 = NEO_RED_CAP_BLUE;
    }

    *nb = gamma2((uint8_t)peak);
    *ng = gamma2((uint8_t)g16);
    *nr = gamma2((uint8_t)r16);
}

static void neo_from_yellow(uint8_t sr, uint8_t sg, uint8_t sb, uint8_t *nr, uint8_t *ng,
                            uint8_t *nb) {
    uint16_t peak;
    uint16_t b16;
    uint8_t bright;

    bright = sensor_max2(sr, sg);
    if (bright < 16u) {
        *nr = 0;
        *ng = 0;
        *nb = 0;
        return;
    }

    peak = (uint16_t)bright * 255u / 170u;
    if (peak > 255u) {
        peak = 255u;
    }

    b16 = (uint16_t)sb * peak / bright;
    if (b16 > 20u) {
        b16 = 20u;
    }

    *nr = gamma2((uint8_t)peak);
    *ng = gamma2((uint8_t)peak);
    *nb = gamma2((uint8_t)b16);
}

static void neo_from_red(uint8_t sr, uint8_t sg, uint8_t sb, uint8_t *nr, uint8_t *ng,
                         uint8_t *nb) {
    uint16_t peak;
    uint16_t g16;
    uint16_t b16;
    uint16_t denom;

    denom = sr;
    if (sg > denom) {
        denom = sg;
    }
    if (denom < 16u) {
        *nr = 0;
        *ng = 0;
        *nb = 0;
        return;
    }

    peak = (uint16_t)denom * 255u / 200u;
    if (peak > 255u) {
        peak = 255u;
    }

    g16 = (uint16_t)sr * peak / denom;
    if (g16 > NEO_GREEN_CAP_RED) {
        g16 = NEO_GREEN_CAP_RED;
    }

    b16 = (uint16_t)sb * peak / denom;
    if (b16 > NEO_BLUE_CAP_RED) {
        b16 = NEO_BLUE_CAP_RED;
    }

    *nr = gamma2((uint8_t)peak);
    *ng = gamma2((uint8_t)g16);
    *nb = gamma2((uint8_t)b16);
}

static void rgb_for_neopixel(uint8_t sr, uint8_t sg, uint8_t sb, uint8_t *nr, uint8_t *ng,
                             uint8_t *nb) {
    uint8_t cr;
    uint8_t cg;
    uint8_t cb;
    uint16_t max;
    uint16_t second;
    uint16_t peak;
    uint16_t ratio_pct;

    enum neo_color_class cls;
    cr = wb_scale(sr, WB_R_NUM);
    cg = wb_scale(sg, WB_G_NUM);
    cb = wb_scale(sb, WB_B_NUM);

    cls = sensor_classify_locked(sr, sg, sb);

    if (cls == NEO_CLS_YELLOW) {
        neo_from_yellow(cr, cg, cb, nr, ng, nb);
        neo_hold_blend(nr, ng, nb, NEO_CLS_YELLOW, 200u);
        return;
    }

    if (cls == NEO_CLS_BLUE) {
        neo_from_blue_cyan(cr, cg, cb, nr, ng, nb);
        neo_hold_blend(nr, ng, nb, NEO_CLS_BLUE, 200u);
        return;
    }

    if (cls == NEO_CLS_RED) {
        neo_from_red(cr, cg, cb, nr, ng, nb);
        neo_hold_blend(nr, ng, nb, NEO_CLS_RED, 200u);
        return;
    }

    max = cr;
    second = 0;
    if (cg >= max) {
        second = max;
        max = cg;
    } else if (cg > second) {
        second = cg;
    }
    if (cb >= max) {
        second = max;
        max = cb;
    } else if (cb > second) {
        second = cb;
    }

    if (max < 16u) {
        *nr = 0;
        *ng = 0;
        *nb = 0;
        return;
    }

    ratio_pct = (max * 100u) / (second + 1u);
    peak = (ratio_pct >= HUE_DOMINANCE_PCT) ? 255u : HUE_SOFT_PEAK;

    *nr = gamma2((uint8_t)((uint16_t)cr * peak / max));
    *ng = gamma2((uint8_t)((uint16_t)cg * peak / max));
    *nb = gamma2((uint8_t)((uint16_t)cb * peak / max));

    neo_hold_blend(nr, ng, nb, NEO_CLS_GENERIC, ratio_pct);
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
    last_r = r;
    last_g = g;
    last_b = b;
    last_rgb_valid = true;
    rgb_for_neopixel(r, g, b, &last_neo_r, &last_neo_g, &last_neo_b);
    spi1_neopixel_set_rgb(last_neo_r, last_neo_g, last_neo_b);
}

static void status_poll(unsigned long ms) {
    uint8_t r = 0;
    uint8_t g = 0;
    uint8_t b = 0;
    char line[64];

    if (!i2c3_apds_sensor_ready()) {
        return;
    }

    if ((ms - last_status_ms) < STATUS_INTERVAL_MS) {
        return;
    }
    last_status_ms = ms;

    if (last_rgb_valid) {
        snprintf(line, sizeof(line), "RGB sen %02X %02X %02X  neo %02X %02X %02X\r\n",
                 last_r, last_g, last_b, last_neo_r, last_neo_g, last_neo_b);
        cdc_puts(line);
        return;
    }

    if (i2c3_apds_read_rgb(&r, &g, &b)) {
        snprintf(line, sizeof(line), "RGB sen %02X %02X %02X\r\n", r, g, b);
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
        last_rgb_valid = false;
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
    last_rgb_valid = false;
    cdc_init();
}

void app_c_status_led_toggle(bool on) {
    status_led_set(on);
}
