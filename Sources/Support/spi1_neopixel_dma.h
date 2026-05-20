/*
 * spi1_neopixel_dma.h — WS2812-over-SPI via SERCOM1 + looping DMAC (Adafruit ZeroDMA style).
 *
 * PA18 MOSI / SERCOM1 PAD2. Call spi1_neopixel_dma_begin() after SPI1 pin/clock setup.
 * To change color, only update the DMA buffer (spi1_neopixel_dma_set_pixel); SPI never stops.
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

/// Start SERCOM1 SPI @ 2.4 MHz and loop DMAC channel 0 → SERCOM1 SPI DATA.
/// Returns false if setup fails (caller may fall back to CPU SPI burst).
bool spi1_neopixel_dma_begin(void);

/// Update GRB in the looping DMA buffer (wire order GRB, not RGB).
void spi1_neopixel_dma_set_pixel(uint8_t green, uint8_t red, uint8_t blue);

bool spi1_neopixel_dma_is_running(void);
