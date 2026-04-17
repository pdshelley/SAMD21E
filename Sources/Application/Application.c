#include <sam.h>
#include "delay.h"
#include "pin-mapping.h"

/*
 * Minimal NeoPixel (WS2812B) driver for the QT Py M0.
 *
 * Data pin : PA18 (NEO_DATA_BIT)  – board pin 11
 * Power pin: PA15 (NEO_PWR_BIT)   – board pin 12, driven HIGH by initVariant()
 *
 * Timing follows the Adafruit SAMD21 bit-bang at 48 MHz / 1 flash wait state:
 *   OUTSET then 8 NOPs → if bit=1: 20 more NOPs → OUTCLR
 *                       → if bit=0: OUTCLR immediately
 *   9 NOPs between bits (or reload byte)
 * Interrupts are disabled for the duration of each frame.
 *
 * Pixel format: GRB (WS2812B order).
 */

#define NUM_PIXELS  1
#define BYTES_PER_PIXEL 3

static uint8_t px[NUM_PIXELS * BYTES_PER_PIXEL]; /* G, R, B */

static void neo_set(uint8_t r, uint8_t g, uint8_t b)
{
  px[0] = g;
  px[1] = r;
  px[2] = b;
}

static uint32_t _neo_last_us = 0;

static void neo_show(void)
{
  /* WS2812B reset: hold data low for ≥ 50 µs between frames */
  while ((micros() - _neo_last_us) < 50)
    ;

  const uint32_t pinMask = 1ul << NEO_DATA_BIT;
  volatile uint32_t *set = &(PORT->Group[PORTA].OUTSET.reg);
  volatile uint32_t *clr = &(PORT->Group[PORTA].OUTCLR.reg);

  const uint8_t *ptr     = px;
  const uint8_t *end     = px + sizeof(px);
  uint8_t        p       = *ptr++;
  uint8_t        bitMask = 0x80;

  __disable_irq();

  for (;;) {
    *set = pinMask;
    asm("nop; nop; nop; nop; nop; nop; nop; nop;");
    if (p & bitMask) {
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop;");
      *clr = pinMask;
    } else {
      *clr = pinMask;
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop;");
    }
    if (bitMask >>= 1) {
      asm("nop; nop; nop; nop; nop; nop; nop; nop; nop;");
    } else {
      if (ptr >= end)
        break;
      p       = *ptr++;
      bitMask = 0x80;
    }
  }

  __enable_irq();
  _neo_last_us = micros();
}

void app_init(void)
{
  /* Configure PA18 as output, start low */
  PORT->Group[PORTA].DIRSET.reg = (1ul << NEO_DATA_BIT);
  PORT->Group[PORTA].OUTCLR.reg = (1ul << NEO_DATA_BIT);

  /* Clear pixel and push one frame so the LED starts off */
  neo_set(0, 0, 0);
  neo_show();
}

void app_main(void)
{
  neo_set(255, 0, 0); neo_show(); delay(100); /* Red   */
  neo_set(0, 255, 0); neo_show(); delay(100); /* Green */
  neo_set(0, 0, 255); neo_show(); delay(100); /* Blue  */
  neo_set(0, 0, 0);   neo_show(); delay(100); /* Off   */
}
