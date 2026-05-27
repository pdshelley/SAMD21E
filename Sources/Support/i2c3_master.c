/*
 * i2c3_master.c — SERCOM3 I2C master on QT Py STEMMA QT (PA16 SDA, PA17 SCL).
 *
 * Same pins as Arduino Wire (D4/D5) but SERCOM3 + mux D so SERCOM1 can run SPI
 * for the onboard NeoPixel. CMSIS only (see i2c3_gclk.c / spi1_gclk.c).
 */

#include "cdc_bridge.h"
#include <sam.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

extern void i2c3_enable_generic_clocks(void);
extern unsigned long millis(void);

void i2c3_master_debug_snapshot(
    uint8_t *enable, uint8_t *busstate, uint8_t *intflag, uint8_t *rxnack);

static void cdc_puts(const char *s) {
    if (!cdc_is_connected()) {
        return;
    }
    const char *p = s;
    while (*p) {
        p++;
    }
    if (p > s) {
        cdc_write((const uint8_t *)s, (uint32_t)(p - s));
        cdc_flush();
        cdc_task();
    }
}

static void cdc_print_snapshot(const char *tag) {
    uint8_t en = 0;
    uint8_t bus = 0;
    uint8_t flags = 0;
    uint8_t nack = 0;
    char line[56];

    i2c3_master_debug_snapshot(&en, &bus, &flags, &nack);
    int n = snprintf(line, sizeof(line), "%sst en=%02X bus=%02X if=%02X nack=%02X\r\n", tag,
                     en, bus, flags, nack);
    if (n > 0) {
        cdc_puts(line);
    }
}

#define I2C3_POLL_LIMIT 100000u

static Sercom *const i2c = SERCOM3;
static uint8_t read_fail_step;
static uint8_t write_fail_step;

static void send_stop(void);
static void txn_prepare(void);

static bool wait_sysop(void) {
    uint32_t n = I2C3_POLL_LIMIT;
    while (i2c->I2CM.SYNCBUSY.bit.SYSOP) {
        if (--n == 0) {
            return false;
        }
    }
    return true;
}

static bool wait_mb(void) {
    uint32_t n = I2C3_POLL_LIMIT;
    while (!(i2c->I2CM.INTFLAG.reg & SERCOM_I2CM_INTFLAG_MB)) {
        if (--n == 0) {
            return false;
        }
    }
    return true;
}

static bool wait_sb(void) {
    uint32_t n = I2C3_POLL_LIMIT;
    while (!(i2c->I2CM.INTFLAG.reg & SERCOM_I2CM_INTFLAG_SB)) {
        if (--n == 0) {
            return false;
        }
    }
    return true;
}

static void bus_force_idle(void) {
    if (!wait_sysop()) {
        return;
    }
    /* Same as Arduino SERCOM::enableWIRE() after ENABLE. */
    i2c->I2CM.STATUS.bit.BUSSTATE = 1;
    while (i2c->I2CM.SYNCBUSY.bit.SYSOP) {
    }
}

static void send_stop(void) {
    if (!wait_sysop()) {
        return;
    }
    i2c->I2CM.CTRLB.reg |= SERCOM_I2CM_CTRLB_CMD(3);
    wait_sysop();
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    bus_force_idle();
}

static void txn_prepare(void) {
    send_stop();
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    bus_force_idle();
}

void i2c3_master_init(void) {
    i2c3_enable_generic_clocks();

    /* PA16 = SERCOM3 PAD0 (SDA), PA17 = PAD1 (SCL), peripheral mux D (PIO_SERCOM_ALT). */
    PORT->Group[0].PINCFG[16].reg = PORT_PINCFG_PMUXEN | PORT_PINCFG_INEN;
    PORT->Group[0].PINCFG[17].reg = PORT_PINCFG_PMUXEN | PORT_PINCFG_INEN;
    PORT->Group[0].PMUX[8].reg = PORT_PMUX_PMUXE(3) | PORT_PMUX_PMUXO(3);

    i2c->I2CM.CTRLA.reg = SERCOM_I2CM_CTRLA_SWRST;
    while (i2c->I2CM.CTRLA.bit.SWRST) {
    }

    /* 100 kHz @ 48 MHz GCLK0 — same formula as Arduino initMasterWIRE(). */
    i2c->I2CM.CTRLA.reg = SERCOM_I2CM_CTRLA_MODE(5) | SERCOM_I2CM_CTRLA_SPEED(0);
    i2c->I2CM.BAUD.reg = SERCOM_I2CM_BAUD_BAUD(228);
    i2c->I2CM.CTRLA.bit.ENABLE = 1;
    while (i2c->I2CM.SYNCBUSY.bit.ENABLE) {
    }

    bus_force_idle();
}

bool i2c3_master_probe(uint8_t addr7) {
    bus_force_idle();
    if (!wait_sysop()) {
        return false;
    }

    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    i2c->I2CM.CTRLB.reg &= ~SERCOM_I2CM_CTRLB_ACKACT;
    i2c->I2CM.ADDR.reg = (uint32_t)addr7 << 1;

    if (!wait_mb()) {
        send_stop();
        return false;
    }
    if (i2c->I2CM.STATUS.bit.RXNACK) {
        send_stop();
        return false;
    }

    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB;
    send_stop();
    return true;
}

uint8_t i2c3_read_fail_step(void) {
    return read_fail_step;
}

bool i2c3_master_read_reg(uint8_t addr7, uint8_t reg, uint8_t *out_byte) {
    if (out_byte == 0) {
        return false;
    }

    read_fail_step = 0;
    bus_force_idle();
    if (!wait_sysop()) {
        read_fail_step = 1u;
        return false;
    }

    /* Write phase: address + register. */
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    if (!wait_sysop()) {
        read_fail_step = 2u;
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_CMD(0);
    if (!wait_sysop()) {
        read_fail_step = 3u;
        send_stop();
        return false;
    }
    i2c->I2CM.ADDR.reg = (uint32_t)addr7 << 1;
    if (!wait_mb() || i2c->I2CM.STATUS.bit.RXNACK) {
        read_fail_step = 4u;
        send_stop();
        return false;
    }
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB;

    if (!wait_sysop()) {
        read_fail_step = 5u;
        send_stop();
        return false;
    }
    i2c->I2CM.DATA.reg = reg;
    if (!wait_mb() || i2c->I2CM.STATUS.bit.RXNACK) {
        read_fail_step = 6u;
        send_stop();
        return false;
    }
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB;

    /* Repeated START + read one byte. */
    if (!wait_sysop()) {
        read_fail_step = 7u;
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_CMD(1);
    if (!wait_sysop()) {
        read_fail_step = 8u;
        send_stop();
        return false;
    }

    if (!wait_sysop()) {
        read_fail_step = 9u;
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg &= (uint32_t)~SERCOM_I2CM_CTRLB_ACKACT;
    if (!wait_sysop()) {
        read_fail_step = 10u;
        send_stop();
        return false;
    }

    i2c->I2CM.ADDR.reg = ((uint32_t)addr7 << 1) | 1u;
    if (!wait_sb() || i2c->I2CM.STATUS.bit.RXNACK) {
        read_fail_step = 11u;
        send_stop();
        return false;
    }

    if (!wait_sysop()) {
        read_fail_step = 12u;
        send_stop();
        return false;
    }
    /* NACK + STOP, then read DATA (do not wait MB first — stalls on SAMD21). */
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_ACKACT | SERCOM_I2CM_CTRLB_CMD(3);
    if (!wait_sysop()) {
        read_fail_step = 13u;
        send_stop();
        return false;
    }

    *out_byte = (uint8_t)i2c->I2CM.DATA.reg;
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    send_stop();
    return true;
}

static bool i2c3_read_byte_rx(bool last, uint8_t *out) {
    uint32_t n = I2C3_POLL_LIMIT;

    if (out == 0) {
        return false;
    }
    while (1) {
        uint8_t flags = (uint8_t)(i2c->I2CM.INTFLAG.reg & 0xFFu);
        if ((flags & SERCOM_I2CM_INTFLAG_MB) || (flags & SERCOM_I2CM_INTFLAG_SB)) {
            break;
        }
        if (--n == 0) {
            return false;
        }
    }
    if (!wait_sysop()) {
        return false;
    }
    if (last) {
        i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_ACKACT | SERCOM_I2CM_CTRLB_CMD(3);
    } else {
        i2c->I2CM.CTRLB.reg &= (uint32_t)~SERCOM_I2CM_CTRLB_ACKACT;
    }
    if (!wait_sysop()) {
        return false;
    }
    *out = (uint8_t)i2c->I2CM.DATA.reg;
    return true;
}

bool i2c3_master_read_bytes(uint8_t addr7, uint8_t reg, uint8_t *buf, uint8_t len) {
    uint8_t i;

    if (buf == 0 || len == 0) {
        return false;
    }

    read_fail_step = 0;
    txn_prepare();
    if (!wait_sysop()) {
        read_fail_step = 1u;
        return false;
    }

    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    if (!wait_sysop()) {
        read_fail_step = 2u;
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_CMD(0);
    if (!wait_sysop()) {
        read_fail_step = 3u;
        send_stop();
        return false;
    }
    i2c->I2CM.ADDR.reg = (uint32_t)addr7 << 1;
    if (!wait_mb() || i2c->I2CM.STATUS.bit.RXNACK) {
        read_fail_step = 4u;
        send_stop();
        return false;
    }
    if (!wait_sysop()) {
        read_fail_step = 5u;
        send_stop();
        return false;
    }
    i2c->I2CM.DATA.reg = reg;
    if (!wait_mb() || i2c->I2CM.STATUS.bit.RXNACK) {
        read_fail_step = 6u;
        send_stop();
        return false;
    }

    if (!wait_sysop()) {
        read_fail_step = 7u;
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_CMD(1);
    if (!wait_sysop()) {
        read_fail_step = 8u;
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg &= (uint32_t)~SERCOM_I2CM_CTRLB_ACKACT;
    if (!wait_sysop()) {
        read_fail_step = 9u;
        send_stop();
        return false;
    }

    i2c->I2CM.ADDR.reg = ((uint32_t)addr7 << 1) | 1u;
    if (!wait_sb() || i2c->I2CM.STATUS.bit.RXNACK) {
        read_fail_step = 10u;
        send_stop();
        return false;
    }

    for (i = 0; i < len; i++) {
        if (!i2c3_read_byte_rx(i == (uint8_t)(len - 1u), &buf[i])) {
            read_fail_step = (uint8_t)(20u + i);
            send_stop();
            return false;
        }
    }

    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    send_stop();
    return true;
}

uint8_t i2c3_write_fail_step(void) {
    return write_fail_step;
}

bool i2c3_master_write_reg(uint8_t addr7, uint8_t reg, uint8_t value) {
    write_fail_step = 0;
    txn_prepare();
    if (!wait_sysop()) {
        write_fail_step = 1u;
        return false;
    }

    i2c->I2CM.CTRLB.reg &= (uint32_t)~SERCOM_I2CM_CTRLB_ACKACT;
    if (!wait_sysop()) {
        write_fail_step = 2u;
        send_stop();
        return false;
    }

    i2c->I2CM.ADDR.reg = (uint32_t)addr7 << 1;
    if (!wait_mb()) {
        write_fail_step = 3u;
        send_stop();
        return false;
    }
    if (i2c->I2CM.STATUS.bit.RXNACK) {
        write_fail_step = 4u;
        send_stop();
        return false;
    }

    if (!wait_sysop()) {
        write_fail_step = 5u;
        send_stop();
        return false;
    }
    i2c->I2CM.DATA.reg = reg;
    if (!wait_mb()) {
        write_fail_step = 6u;
        send_stop();
        return false;
    }
    if (i2c->I2CM.STATUS.bit.RXNACK) {
        write_fail_step = 7u;
        send_stop();
        return false;
    }

    if (!wait_sysop()) {
        write_fail_step = 8u;
        send_stop();
        return false;
    }
    i2c->I2CM.DATA.reg = value;
    if (!wait_mb()) {
        write_fail_step = 9u;
        send_stop();
        return false;
    }
    if (i2c->I2CM.STATUS.bit.RXNACK) {
        write_fail_step = 10u;
        send_stop();
        return false;
    }

    send_stop();
    return true;
}

/* APDS-9999 on STEMMA QT (0x52). Not APDS-9960 (ID 0x92/0xAB, ENABLE 0x80). */
#define APDS_ADDR 0x52u
#define APDS9999_REG_MAIN_CTRL 0x00u
#define APDS9999_REG_LS_MEAS_RATE 0x04u
#define APDS9999_REG_LS_GAIN 0x05u
#define APDS9999_REG_PART_ID 0x06u
#define APDS9999_PART_ID 0xC2u
#define APDS9999_REG_MAIN_STATUS 0x07u
#define APDS9999_STATUS_LIGHT_READY 0x08u
#define APDS9999_REG_LS_GREEN_0 0x0Du
#define APDS9999_REG_LS_BLUE_0 0x10u
#define APDS9999_REG_LS_RED_0 0x13u
#define APDS9999_CH_BYTES 3u
/* MAIN_CTRL: light enable (1) + RGB mode (2) */
#define APDS9999_MAIN_RGB 0x06u
/* LS_MEAS_RATE 0x22 uses RES_18BIT — max count before scale to 0..255 */
#define APDS9999_RAW_MAX 0x3FFFFu

static bool apds_sensor_ready;
static uint8_t apds_enable_fail_step;

static void delay_ms(unsigned long ms) {
    unsigned long start = millis();
    while ((millis() - start) < ms) {
        cdc_task();
    }
}

bool i2c3_apds_sensor_ready(void) {
    return apds_sensor_ready;
}

static uint32_t apds_u20_from_buf(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)(p[2] & 0x0Fu) << 16);
}

static bool apds_wait_light_ready(void) {
    unsigned tries = 0;

    for (tries = 0; tries < 40u; tries++) {
        uint8_t st = 0;
        if (!i2c3_master_read_reg(APDS_ADDR, APDS9999_REG_MAIN_STATUS, &st)) {
            return false;
        }
        if ((st & APDS9999_STATUS_LIGHT_READY) != 0u) {
            return true;
        }
        delay_ms(5);
    }
    return false;
}

static uint8_t scale_u20(uint32_t raw) {
    uint32_t v;

    raw &= APDS9999_RAW_MAX;
    v = (raw * 255u) / APDS9999_RAW_MAX;
    if (v > 255u) {
        v = 255u;
    }
    if (v == 0u && raw > 0u) {
        v = 1u;
    }
    return (uint8_t)v;
}

void i2c3_bus_recover(void) {
    send_stop();
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    bus_force_idle();
}

bool i2c3_apds_enable(void) {
    apds_enable_fail_step = 0;
    apds_sensor_ready = false;
    i2c3_bus_recover();
    delay_ms(2);

    /* 18-bit resolution, 100 ms rate (Adafruit APDS9999 defaults). */
    if (!i2c3_master_write_reg(APDS_ADDR, APDS9999_REG_LS_MEAS_RATE, 0x22u)) {
        apds_enable_fail_step = 1u;
        return false;
    }
    if (!i2c3_master_write_reg(APDS_ADDR, APDS9999_REG_LS_GAIN, 0x01u)) {
        apds_enable_fail_step = 2u;
        return false;
    }
    if (!i2c3_master_write_reg(APDS_ADDR, APDS9999_REG_MAIN_CTRL, APDS9999_MAIN_RGB)) {
        apds_enable_fail_step = 3u;
        return false;
    }

    delay_ms(150);
    i2c3_bus_recover();
    apds_sensor_ready = true;
    return true;
}

uint8_t i2c3_apds_enable_fail_step(void) {
    return apds_enable_fail_step;
}

static bool apds_read_channel(uint8_t reg, uint32_t *raw) {
    uint8_t ch[APDS9999_CH_BYTES];

    if (raw == 0) {
        return false;
    }
    if (!i2c3_master_read_bytes(APDS_ADDR, reg, ch, APDS9999_CH_BYTES)) {
        return false;
    }
    *raw = apds_u20_from_buf(ch);
    return true;
}

bool i2c3_apds_read_rgb(uint8_t *r, uint8_t *g, uint8_t *b) {
    uint32_t r20 = 0;
    uint32_t g20 = 0;
    uint32_t b20 = 0;

    if (r == 0 || g == 0 || b == 0) {
        return false;
    }
    if (!apds_sensor_ready) {
        return false;
    }

    i2c3_bus_recover();
    (void)apds_wait_light_ready();

    /* Separate pointer per channel (SERCOM burst may not auto-increment on 9999). */
    if (!apds_read_channel(APDS9999_REG_LS_GREEN_0, &g20)) {
        return false;
    }
    if (!apds_read_channel(APDS9999_REG_LS_BLUE_0, &b20)) {
        return false;
    }
    if (!apds_read_channel(APDS9999_REG_LS_RED_0, &r20)) {
        return false;
    }

    *g = scale_u20(g20);
    *b = scale_u20(b20);
    *r = scale_u20(r20);
    return true;
}

void i2c3_apds_debug_rgb_raw_cdc(void) {
    uint32_t r20 = 0;
    uint32_t g20 = 0;
    uint32_t b20 = 0;
    char line[56];

    if (!apds_sensor_ready) {
        return;
    }
    i2c3_bus_recover();
    (void)apds_wait_light_ready();
    if (!apds_read_channel(APDS9999_REG_LS_GREEN_0, &g20)) {
        return;
    }
    if (!apds_read_channel(APDS9999_REG_LS_BLUE_0, &b20)) {
        return;
    }
    if (!apds_read_channel(APDS9999_REG_LS_RED_0, &r20)) {
        return;
    }
    snprintf(line, sizeof(line), "APDS raw G=%lu B=%lu R=%lu\r\n", (unsigned long)g20,
             (unsigned long)b20, (unsigned long)r20);
    cdc_puts(line);
}

void i2c3_master_debug_snapshot(
    uint8_t *enable, uint8_t *busstate, uint8_t *intflag, uint8_t *rxnack) {
    if (enable) {
        *enable = i2c->I2CM.CTRLA.bit.ENABLE ? 1u : 0u;
    }
    if (busstate) {
        *busstate = (uint8_t)i2c->I2CM.STATUS.bit.BUSSTATE;
    }
    if (intflag) {
        *intflag = (uint8_t)(i2c->I2CM.INTFLAG.reg & 0xFFu);
    }
    if (rxnack) {
        *rxnack = i2c->I2CM.STATUS.bit.RXNACK ? 1u : 0u;
    }
}

/* Boot-time isolate test (all CDC from C). Call after i2c3_master_init(). */
void i2c3_run_isolate_test_c(void) {
    bool ack08 = false;
    bool ack52 = false;
    uint8_t part_id = 0;
    bool part_ok = false;
    bool apds_on = false;
    char line[48];

    i2c3_bus_recover();

    cdc_puts("I2C isolate (boot, C):\r\n");
    cdc_print_snapshot("pre ");

    ack08 = i2c3_master_probe(0x08u);
    ack52 = i2c3_master_probe(0x52u);
    i2c3_bus_recover();
    part_ok = i2c3_master_read_reg(APDS_ADDR, APDS9999_REG_PART_ID, &part_id);

    if (part_ok && part_id == APDS9999_PART_ID) {
        apds_on = i2c3_apds_enable();
    }

    cdc_puts(ack08 ? "probe 0x08: ACK\r\n" : "probe 0x08: no ACK\r\n");
    cdc_puts(ack52 ? "probe 0x52: ACK\r\n" : "probe 0x52: no ACK\r\n");
    if (part_ok) {
        snprintf(line, sizeof(line), "APDS-9999 ID=0x%02X (%s)\r\n", part_id,
                 part_id == APDS9999_PART_ID ? "OK" : "unexpected");
    } else {
        snprintf(line, sizeof(line), "APDS-9999 ID=0x%02X (read failed step %u)\r\n", part_id,
                 (unsigned)i2c3_read_fail_step());
    }
    cdc_puts(line);
    if (apds_on) {
        cdc_puts("APDS-9999 enable: OK\r\n");
        i2c3_apds_debug_rgb_raw_cdc();
    } else if (part_ok && part_id == APDS9999_PART_ID) {
        snprintf(line, sizeof(line), "APDS-9999 enable: failed (en %u wr %u)\r\n",
                 (unsigned)i2c3_apds_enable_fail_step(), (unsigned)i2c3_write_fail_step());
        cdc_puts(line);
    } else {
        cdc_puts("APDS-9999 enable: skipped\r\n");
    }
    cdc_print_snapshot("post ");
    cdc_puts("I2C isolate done\r\n");
}

/*
 * Staged bring-up from app_main (C only, no Swift SERCOM/PM access).
 *  - 5.0 s: init SERCOM3 I2C (LA should see traffic at 5.5 s)
 *  - 5.5 s: two wire probes, no CDC
 *  - after host opens CDC: print isolate log once
 */
static uint8_t i2c3_poll_stage;

bool i2c3_staged_bringup_done(void) {
    return i2c3_poll_stage >= 3u;
}

void i2c3_poll(unsigned long ms) {
    if (i2c3_poll_stage >= 3u) {
        return;
    }

    if (i2c3_poll_stage == 0u) {
        if (ms < 5000u) {
            return;
        }
        i2c3_master_init();
        i2c3_poll_stage = 1u;
        return;
    }

    if (i2c3_poll_stage == 1u) {
        if (ms < 5500u) {
            return;
        }
        (void)i2c3_master_probe(0x08u);
        (void)i2c3_master_probe(0x52u);
        i2c3_poll_stage = 2u;
        return;
    }

    if (i2c3_poll_stage == 2u && cdc_is_connected()) {
        i2c3_run_isolate_test_c();
        i2c3_poll_stage = 3u;
    }
}
