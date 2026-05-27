//
//  BridgingHeader.h
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

#pragma once
#include <stdint.h>
#include <stdbool.h>

/// Millisecond delay backed by SysTick (delay.c)
extern void delay(unsigned long ms);

/// Returns the number of milliseconds elapsed since startup, backed by SysTick (delay.c).
/// Overflows approximately every 49 days.
extern unsigned long millis(void);

/// Sub-microsecond busy wait (delay.c / delay.h).
extern void delay_busy_microseconds(unsigned int usec);

/// Volatile Register Read
///
/// At some point in the future this might be added to Swift, if so this should
/// be removed in favor of a Swift only approach.
extern uint32_t _volatileRegisterReadUInt32(uintptr_t address);
extern uint16_t _volatileRegisterReadUInt16(uintptr_t address);

/// Volatile Register Read
///
/// At some point in the future this might be added to Swift, if so this should
/// be removed in favor of a Swift only approach.
extern void _volatileRegisterWriteUInt32(uintptr_t address, uint32_t value);
extern void _volatileRegisterWriteUInt16(uintptr_t address, uint16_t value);

/// Enable GCLK0 on SERCOM0 core + SERCOM slow (see spi0_gclk.c).
extern void spi0_enable_generic_clocks(void); // TODO: Switch to the Swift versions so this can be removed.

/// Enable GCLK0 on SERCOM1 core + SERCOM slow (see spi1_gclk.c).
extern void spi1_enable_generic_clocks(void);
extern void dmac_enable_clocks(void);

/// SERCOM1 SPI + DMAC NeoPixel (CMSIS; avoids Swift HardFault on configure).
extern bool spi1_neopixel_init(void);
extern bool spi1_neopixel_ready(void);
extern void spi1_neopixel_set_rgb(uint8_t red, uint8_t green, uint8_t blue);

/// Enable GCLK0 on SERCOM3 core + SERCOM slow for STEMMA I2C (see i2c3_gclk.c).
extern void i2c3_enable_generic_clocks(void);

/// SERCOM3 I2C on PA16/PA17 (STEMMA; SERCOM1 reserved for NeoPixel SPI).
extern void i2c3_master_init(void);
extern bool i2c3_master_probe(uint8_t addr7);
extern bool i2c3_master_write_reg(uint8_t addr7, uint8_t reg, uint8_t value);
extern uint8_t i2c3_write_fail_step(void);
extern bool i2c3_master_read_reg(uint8_t addr7, uint8_t reg, uint8_t *out_byte);
extern bool i2c3_master_read_bytes(uint8_t addr7, uint8_t reg, uint8_t *buf, uint8_t len);
extern uint8_t i2c3_read_fail_step(void);
extern void i2c3_bus_recover(void);
extern bool i2c3_apds_enable(void);
extern uint8_t i2c3_apds_enable_fail_step(void);
extern bool i2c3_apds_sensor_ready(void);
extern bool i2c3_apds_read_rgb(uint8_t *r, uint8_t *g, uint8_t *b);
extern void i2c3_apds_debug_rgb_raw_cdc(void);
extern void i2c3_master_debug_snapshot(
    uint8_t *enable, uint8_t *busstate, uint8_t *intflag, uint8_t *rxnack);
extern void i2c3_run_isolate_test_c(void);
extern void i2c3_poll(unsigned long ms);
extern bool i2c3_staged_bringup_done(void);

/* Hybrid app: C I2C/APDS in app_c_main.c, Swift SPI1 NeoPixel in Application.swift */
extern void app_c_platform_init(void);
extern void app_c_status_led_toggle(bool on);
extern void app_c_main_poll(unsigned long ms);
extern bool app_c_may_configure_spi(void);
extern bool app_c_color_loop_active(void);
extern void app_c_notify_spi_ready(void);
extern bool app_c_apds_read_rgb(uint8_t *r, uint8_t *g, uint8_t *b);

extern bool user_row_write_mac_c(
    uint8_t b0,
    uint8_t b1,
    uint8_t b2,
    uint8_t b3,
    uint8_t b4,
    uint8_t b5
);

#include "cdc_bridge.h"
