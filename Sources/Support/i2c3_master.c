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

bool i2c3_master_read_reg(uint8_t addr7, uint8_t reg, uint8_t *out_byte) {
    if (out_byte == 0) {
        return false;
    }

    bus_force_idle();
    if (!wait_sysop()) {
        return false;
    }

    /* Write phase: address + register. */
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    i2c->I2CM.CTRLB.reg &= ~SERCOM_I2CM_CTRLB_ACKACT;
    i2c->I2CM.ADDR.reg = (uint32_t)addr7 << 1;
    if (!wait_mb() || i2c->I2CM.STATUS.bit.RXNACK) {
        send_stop();
        return false;
    }
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB;

    if (!wait_sysop()) {
        send_stop();
        return false;
    }
    i2c->I2CM.DATA.reg = reg;
    if (!wait_mb() || i2c->I2CM.STATUS.bit.RXNACK) {
        send_stop();
        return false;
    }
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB;

    /* Repeated START + read one byte. */
    if (!wait_sysop()) {
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_CMD(1);
    if (!wait_sysop()) {
        send_stop();
        return false;
    }

    i2c->I2CM.ADDR.reg = ((uint32_t)addr7 << 1) | 1u;
    if (!wait_sb() || i2c->I2CM.STATUS.bit.RXNACK) {
        send_stop();
        return false;
    }
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_SB;

    if (!wait_sysop()) {
        send_stop();
        return false;
    }
    i2c->I2CM.CTRLB.reg = SERCOM_I2CM_CTRLB_ACKACT | SERCOM_I2CM_CTRLB_CMD(3);
    if (!wait_sysop()) {
        send_stop();
        return false;
    }

    *out_byte = (uint8_t)i2c->I2CM.DATA.reg;
    i2c->I2CM.INTFLAG.reg = SERCOM_I2CM_INTFLAG_MB | SERCOM_I2CM_INTFLAG_SB;
    bus_force_idle();
    return true;
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
    char line[72];

    cdc_puts("I2C isolate (boot, C):\r\n");
    cdc_print_snapshot("init ");

    ack08 = i2c3_master_probe(0x08u);
    ack52 = i2c3_master_probe(0x52u);
    part_ok = i2c3_master_read_reg(0x52u, 0x06u, &part_id);

    snprintf(line, sizeof(line),
             "probe 0x08: %s\r\nprobe 0x52: %s\r\nAPDS PART_ID=0x%02X (%s)\r\n",
             ack08 ? "ACK" : "no ACK", ack52 ? "ACK" : "no ACK", part_id,
             part_ok ? (part_id == 0xC2u ? "OK" : "unexpected") : "read failed");
    cdc_puts(line);
    cdc_puts("I2C isolate done\r\n");
}

/*
 * Staged bring-up from app_main (C only, no Swift SERCOM/PM access).
 *  - 5.0 s: init SERCOM3 I2C (LA should see traffic at 5.5 s)
 *  - 5.5 s: two wire probes, no CDC
 *  - after host opens CDC: print isolate log once
 */
void i2c3_poll(unsigned long ms) {
    static uint8_t stage;

    if (stage >= 3u) {
        return;
    }

    if (stage == 0u) {
        if (ms < 5000u) {
            return;
        }
        i2c3_master_init();
        stage = 1u;
        return;
    }

    if (stage == 1u) {
        if (ms < 5500u) {
            return;
        }
        (void)i2c3_master_probe(0x08u);
        (void)i2c3_master_probe(0x52u);
        stage = 2u;
        return;
    }

    if (stage == 2u && cdc_is_connected()) {
        i2c3_run_isolate_test_c();
        stage = 3u;
    }
}
