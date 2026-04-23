#pragma once
#include <stdint.h>
#include <stdbool.h>

/// Initialize the USB clock, enable the peripheral, and start TinyUSB.
/// Call once from appInit() before the main loop.
void cdc_init(void);

/// Drive the TinyUSB device stack. Must be called on every iteration of the
/// main loop — this is what processes USB events and moves data in/out of the
/// CDC FIFOs.
void cdc_task(void);

/// Returns true when a CDC host (terminal) has the port open.
bool cdc_is_connected(void);

/// Write up to `len` bytes from `buf` into the CDC TX FIFO.
/// Returns the number of bytes actually queued. Does not flush.
uint32_t cdc_write(const uint8_t *buf, uint32_t len);

/// Write one byte (safe from Swift: avoids passing a transient stack pointer into `cdc_write`).
uint32_t cdc_write_byte(uint8_t b);

/// Free space remaining in the CDC TX FIFO (TinyUSB `tud_cdc_write_available`).
uint32_t cdc_write_available(void);

/// Flush the CDC TX FIFO, sending any buffered bytes to the host.
void cdc_flush(void);
