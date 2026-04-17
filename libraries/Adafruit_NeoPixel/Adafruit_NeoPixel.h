/*!
 * @file Adafruit_NeoPixel.h
 *
 * Stripped-down version retaining only what is used by Application.cpp:
 *   - Adafruit_NeoPixel(n, pin, type) constructor + destructor
 *   - begin(), show(), setBrightness(), setPixelColor(n, uint32_t),
 *     Color(r,g,b), clear()
 *   - canShow() (called internally by show())
 *   - setPin(), updateLength(), updateType() (called by constructor)
 */

#ifndef ADAFRUIT_NEOPIXEL_H
#define ADAFRUIT_NEOPIXEL_H

#include <Arduino.h>

#define NEO_GRB ((1 << 6) | (1 << 4) | (0 << 2) | (2)) ///< Transmit as G,R,B
#define NEO_KHZ800 0x0000 ///< 800 KHz data transmission

typedef uint16_t neoPixelType; ///< 3rd arg to Adafruit_NeoPixel constructor

class Adafruit_NeoPixel {

public:
  Adafruit_NeoPixel(uint16_t n, int16_t pin = 6,
                    neoPixelType type = NEO_GRB + NEO_KHZ800);
  ~Adafruit_NeoPixel();

  bool begin(void);
  void show(void);
  void setPin(int16_t p);
  void setPixelColor(uint16_t n, uint32_t c);
  void setBrightness(uint8_t);
  void clear(void);
  void updateLength(uint16_t n);
  void updateType(neoPixelType t);

  bool canShow(void) {
    uint32_t now = micros();
    if (endTime > now) {
      endTime = now;
    }
    return (now - endTime) >= 300L;
  }

  static uint32_t Color(uint8_t r, uint8_t g, uint8_t b) {
    return ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
  }

protected:
  bool begun;
  uint16_t numLEDs;
  uint16_t numBytes;
  int16_t pin;
  uint8_t brightness;
  uint8_t *pixels;
  uint8_t rOffset;
  uint8_t gOffset;
  uint8_t bOffset;
  uint8_t wOffset;
  uint32_t endTime;

};

#endif // ADAFRUIT_NEOPIXEL_H
