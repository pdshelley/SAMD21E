/*!
 * @file Adafruit_NeoPixel.cpp
 */

#include "Adafruit_NeoPixel.h"

/*!
  @brief   NeoPixel constructor when length, pin and pixel type are known
           at compile-time.
*/
Adafruit_NeoPixel::Adafruit_NeoPixel(uint16_t n, int16_t p, neoPixelType t)
    : begun(false), brightness(0), pixels(NULL), endTime(0) {
  updateType(t);
  updateLength(n);
  setPin(p);
}

/*!
  @brief   Deallocate Adafruit_NeoPixel object, set data pin back to INPUT.
*/
Adafruit_NeoPixel::~Adafruit_NeoPixel() {
  free(pixels);
  if (pin >= 0)
    pinMode(pin, INPUT);
}

/*!
  @brief   Configure NeoPixel pin for output.
  @returns False if we weren't able to claim resources required
*/
bool Adafruit_NeoPixel::begin(void) {
  if (pin >= 0) {
    pinMode(pin, OUTPUT);
    digitalWrite(pin, LOW);
  } else {
    begun = false;
    return false;
  }
  begun = true;
  return true;
}

/*!
  @brief   Change the length of a previously-declared Adafruit_NeoPixel
           strip object. Old data is deallocated and new data is cleared.
*/
void Adafruit_NeoPixel::updateLength(uint16_t n) {
  free(pixels);
  numBytes = n * ((wOffset == rOffset) ? 3 : 4);
  if ((pixels = (uint8_t *)malloc(numBytes))) {
    memset(pixels, 0, numBytes);
    numLEDs = n;
  } else {
    numLEDs = numBytes = 0;
  }
}

/*!
  @brief   Change the pixel format of a previously-declared
           Adafruit_NeoPixel strip object.
*/
void Adafruit_NeoPixel::updateType(neoPixelType t) {
  bool oldThreeBytesPerPixel = (wOffset == rOffset);

  wOffset = (t >> 6) & 0b11;
  rOffset = (t >> 4) & 0b11;
  gOffset = (t >> 2) & 0b11;
  bOffset = t & 0b11;

  if (pixels) {
    bool newThreeBytesPerPixel = (wOffset == rOffset);
    if (newThreeBytesPerPixel != oldThreeBytesPerPixel)
      updateLength(numLEDs);
  }
}

/*!
  @brief   Transmit pixel data in RAM to NeoPixels (SAMD21, 800 KHz).
*/
void Adafruit_NeoPixel::show(void) {

  if (!pixels)
    return;

  while (!canShow())
    ;

  uint8_t *ptr, *end, p, bitMask, portNum;
  uint32_t pinMask;

  portNum = g_APinDescription[pin].ulPort;
  pinMask = 1ul << g_APinDescription[pin].ulPin;
  ptr = pixels;
  end = ptr + numBytes;
  p = *ptr++;
  bitMask = 0x80;

  volatile uint32_t *set = &(PORT->Group[portNum].OUTSET.reg),
                    *clr = &(PORT->Group[portNum].OUTCLR.reg);

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
      p = *ptr++;
      bitMask = 0x80;
    }
  }

  endTime = micros();
}

/*!
  @brief   Set/change the NeoPixel output pin number.
*/
void Adafruit_NeoPixel::setPin(int16_t p) {
  if (begun && (pin >= 0))
    pinMode(pin, INPUT);
  pin = p;
  if (begun) {
    pinMode(p, OUTPUT);
    digitalWrite(p, LOW);
  }
}

/*!
  @brief   Set a pixel's color using a 32-bit 'packed' RGB or RGBW value.
*/
void Adafruit_NeoPixel::setPixelColor(uint16_t n, uint32_t c) {
  if (n < numLEDs) {
    uint8_t *p, r = (uint8_t)(c >> 16), g = (uint8_t)(c >> 8), b = (uint8_t)c;
    if (brightness) {
      r = (r * brightness) >> 8;
      g = (g * brightness) >> 8;
      b = (b * brightness) >> 8;
    }
    if (wOffset == rOffset) {
      p = &pixels[n * 3];
    } else {
      p = &pixels[n * 4];
      uint8_t w = (uint8_t)(c >> 24);
      p[wOffset] = brightness ? ((w * brightness) >> 8) : w;
    }
    p[rOffset] = r;
    p[gOffset] = g;
    p[bOffset] = b;
  }
}

/*!
  @brief   Adjust output brightness.
*/
void Adafruit_NeoPixel::setBrightness(uint8_t b) {
  uint8_t newBrightness = b + 1;
  if (newBrightness != brightness) {
    uint8_t c, *ptr = pixels,
               oldBrightness = brightness - 1;
    uint16_t scale;
    if (oldBrightness == 0)
      scale = 0;
    else if (b == 255)
      scale = 65535 / oldBrightness;
    else
      scale = (((uint16_t)newBrightness << 8) - 1) / oldBrightness;
    for (uint16_t i = 0; i < numBytes; i++) {
      c = *ptr;
      *ptr++ = (c * scale) >> 8;
    }
    brightness = newBrightness;
  }
}

/*!
  @brief   Fill the whole NeoPixel strip with 0 / black / off.
*/
void Adafruit_NeoPixel::clear(void) { memset(pixels, 0, numBytes); }
