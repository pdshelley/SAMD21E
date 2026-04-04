#include <Adafruit_NeoPixel.h>

#define PIN        11
#define NUMPIXELS  1

Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);

void setup() {
  pixels.begin();
  pixels.setBrightness(2);
}

void loop() {
  pixels.setPixelColor(0, pixels.Color(255, 0, 0));  // Red
  pixels.show();
  delay(100);

  pixels.setPixelColor(0, pixels.Color(0, 255, 0));  // Green
  pixels.show();
  delay(100);

  pixels.setPixelColor(0, pixels.Color(0, 0, 255));  // Blue
  pixels.show();
  delay(100);

  pixels.clear();
  pixels.show();
  delay(100);
}
