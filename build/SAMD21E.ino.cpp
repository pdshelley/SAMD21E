#include <Adafruit_NeoPixel.h>

#define PIN        11   // NeoPixel pin
#define NUMPIXELS  1    // One pixel

Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);

void setup() {
  pixels.begin();           // Initialize NeoPixel
  pixels.setBrightness(2); // Low brightness (0-255)
}

void loop() {
  pixels.setPixelColor(0, pixels.Color(255, 0, 0));  // Red
  pixels.show();
  delay(1000);

  pixels.setPixelColor(0, pixels.Color(0, 255, 0));  // Green
  pixels.show();
  delay(1000);

  pixels.setPixelColor(0, pixels.Color(0, 0, 255));  // Blue
  pixels.show();
  delay(1000);

  pixels.clear();           // Off
  pixels.show();
  delay(1000);
}