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

/// Flush the CDC TX FIFO, sending any buffered bytes to the host.
void cdc_flush(void);
