
#include "Adafruit_NeoPixel.h"

#if defined(ARDUINO_ARCH_MBED)
#include "mbed.h"  // Needed for DigitalOut and PinName
#endif

/*!
  @brief   NeoPixel constructor when length, pin and pixel type are known
           at compile-time.
  @param   n  Number of NeoPixels in strand.
  @param   p  Arduino pin number which will drive the NeoPixel data in.
  @param   t  Pixel type -- add together NEO_* constants defined in
              Adafruit_NeoPixel.h, for example NEO_GRB+NEO_KHZ800 for
              NeoPixels expecting an 800 KHz (vs 400 KHz) data stream
              with color bytes expressed in green, red, blue order per
              pixel.
  @return  Adafruit_NeoPixel object. Call the begin() function before use.
*/
Adafruit_NeoPixel::Adafruit_NeoPixel(uint16_t n, int16_t p, neoPixelType t)
    : begun(false), brightness(0), pixels(NULL), endTime(0) {
  updateType(t);
  updateLength(n);
  setPin(p);
}

/*!
  @brief   "Empty" NeoPixel constructor when length, pin and/or pixel type
           are not known at compile-time, and must be initialized later with
           updateType(), updateLength() and setPin().
  @return  Adafruit_NeoPixel object. Call the begin() function before use.
  @note    This function is deprecated, here only for old projects that
           may still be calling it. New projects should instead use the
           'new' keyword with the first constructor syntax (length, pin,
           type).
*/
Adafruit_NeoPixel::Adafruit_NeoPixel()
    :
#if defined(NEO_KHZ400)
      is800KHz(true),
#endif
      begun(false), numLEDs(0), numBytes(0), pin(-1), brightness(0),
      pixels(NULL), rOffset(1), gOffset(0), bOffset(2), wOffset(1), endTime(0) {
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
           Pin number and pixel format are unchanged.
  @param   n  New length of strip, in pixels.
  @note    This function is deprecated, here only for old projects that
           may still be calling it. New projects should instead use the
           'new' keyword with the first constructor syntax (length, pin,
           type).
*/
void Adafruit_NeoPixel::updateLength(uint16_t n) {
  free(pixels); // Free existing data (if any)

  // Allocate new data -- note: ALL PIXELS ARE CLEARED
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
           Adafruit_NeoPixel strip object. If format changes from one of
           the RGB variants to an RGBW variant (or RGBW to RGB), the old
           data will be deallocated and new data is cleared. Otherwise,
           the old data will remain in RAM and is not reordered to the
           new format, so it's advisable to follow up with clear().
  @param   t  Pixel type -- add together NEO_* constants defined in
              Adafruit_NeoPixel.h, for example NEO_GRB+NEO_KHZ800 for
              NeoPixels expecting an 800 KHz (vs 400 KHz) data stream
              with color bytes expressed in green, red, blue order per
              pixel.
  @note    This function is deprecated, here only for old projects that
           may still be calling it. New projects should instead use the
           'new' keyword with the first constructor syntax
           (length, pin, type).
*/
void Adafruit_NeoPixel::updateType(neoPixelType t) {
  bool oldThreeBytesPerPixel = (wOffset == rOffset); // false if RGBW

  wOffset = (t >> 6) & 0b11; // See notes in header file
  rOffset = (t >> 4) & 0b11; // regarding R/G/B/W offsets
  gOffset = (t >> 2) & 0b11;
  bOffset = t & 0b11;
#if defined(NEO_KHZ400)
  is800KHz = (t < 256); // 400 KHz flag is 1<<8
#endif

  // If bytes-per-pixel has changed (and pixel data was previously
  // allocated), re-allocate to new size. Will clear any data.
  if (pixels) {
    bool newThreeBytesPerPixel = (wOffset == rOffset);
    if (newThreeBytesPerPixel != oldThreeBytesPerPixel)
      updateLength(numLEDs);
  }
}


#if defined(ARDUINO_ARCH_CH32)

// F_CPU is defined to SystemCoreClock (not constant number)
#if SYSCLK_FREQ_144MHz_HSE == 144000000 || SYSCLK_FREQ_HSE == 144000000 || \
  SYSCLK_FREQ_144MHz_HSI == 144000000 || SYSCLK_FREQ_HSI == 144000000
#define CH32_F_CPU 144000000

#elif SYSCLK_FREQ_120MHz_HSE == 120000000 || SYSCLK_FREQ_HSE == 120000000 || \
  SYSCLK_FREQ_120MHz_HSI == 120000000 || SYSCLK_FREQ_HSI == 120000000
#define CH32_F_CPU 120000000

#elif SYSCLK_FREQ_96MHz_HSE == 96000000 || SYSCLK_FREQ_HSE == 96000000 || \
  SYSCLK_FREQ_96MHz_HSI == 96000000 || SYSCLK_FREQ_HSI == 96000000
#define CH32_F_CPU 96000000

#elif SYSCLK_FREQ_72MHz_HSE == 72000000 || SYSCLK_FREQ_HSE == 72000000 || \
  SYSCLK_FREQ_72MHz_HSI == 72000000 || SYSCLK_FREQ_HSI == 72000000
#define CH32_F_CPU 72000000

#elif SYSCLK_FREQ_56MHz_HSE == 56000000 || SYSCLK_FREQ_HSE == 56000000 || \
  SYSCLK_FREQ_56MHz_HSI == 56000000 || SYSCLK_FREQ_HSI == 56000000
#define CH32_F_CPU 56000000

#elif SYSCLK_FREQ_48MHz_HSE == 48000000 || SYSCLK_FREQ_HSE == 48000000 || \
  SYSCLK_FREQ_48MHz_HSI == 48000000 || SYSCLK_FREQ_HSI == 48000000
#define CH32_F_CPU 48000000

#endif

static void ch32Show(GPIO_TypeDef* ch_port, uint32_t ch_pin, uint8_t* pixels, uint32_t numBytes, bool is800KHz) {
  // not support 400khz
  if (!is800KHz) return;

  volatile uint32_t* set = &ch_port->BSHR;
  volatile uint32_t* clr = &ch_port->BCR;

  uint8_t* ptr = pixels;
  uint8_t* end = ptr + numBytes;
  uint8_t p = *ptr++;
  uint8_t bitMask = 0x80;

  // NVIC_DisableIRQ(SysTicK_IRQn);

  while (1) {
    if (p & bitMask) { // ONE
      // High 800ns
      *set = ch_pin;
      __asm volatile ("nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop;"
#if CH32_F_CPU >= 56000000
        "nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 72000000
        "nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 96000000
        "nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 120000000
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 144000000
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
        );

      // Low 450ns
      *clr = ch_pin;
      __asm volatile ("nop; nop;"
#if CH32_F_CPU >= 56000000
        "nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 72000000
        "nop; nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 96000000
        "nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 120000000
        "nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 144000000
        "nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
        );
    } else {   // ZERO
      // High 400ns
      *set = ch_pin;
      __asm volatile ("nop; nop; nop; nop; nop; nop; nop; nop;"
#if CH32_F_CPU >= 56000000
        "nop; nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 72000000
        "nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 96000000
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 120000000
        "nop; nop; nop; "
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 144000000
        "nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
        );

      // Low 850ns
      *clr = ch_pin;
      __asm volatile ("nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop;"
#if CH32_F_CPU >= 56000000
        "nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 72000000
        "nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 96000000
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 120000000
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop;"
#endif
#if CH32_F_CPU >= 144000000
        "nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;"
#endif
        );
    }

    if (bitMask >>= 1) {
      // Move on to the next pixel
      asm("nop;");
    }
    else {
      if (ptr >= end) {
        break;
      }
      p = *ptr++;
      bitMask = 0x80;
    }
  }

  // NVIC_EnableIRQ(SysTicK_IRQn);
}
#endif

/*!
  @brief   Transmit pixel data in RAM to NeoPixels.
  @note    On most architectures, interrupts are temporarily disabled in
           order to achieve the correct NeoPixel signal timing. This means
           that the Arduino millis() and micros() functions, which require
           interrupts, will lose small intervals of time whenever this
           function is called (about 30 microseconds per RGB pixel, 40 for
           RGBW pixels). There's no easy fix for this, but a few
           specialized alternative or companion libraries exist that use
           very device-specific peripherals to work around it.
*/
void Adafruit_NeoPixel::show(void) {

  if (!pixels)
    return;

  // Data latch = 300+ microsecond pause in the output stream. Rather than
  // put a delay at the end of the function, the ending time is noted and
  // the function will simply hold off (if needed) on issuing the
  // subsequent round of data until the latch time has elapsed. This
  // allows the mainline code to start generating the next frame of data
  // rather than stalling for the latch.
  while (!canShow())
    ;
    // endTime is a private member (rather than global var) so that multiple
    // instances on different pins can be quickly issued in succession (each
    // instance doesn't delay the next).

    // In order to make this code runtime-configurable to work with any pin,
    // SBI/CBI instructions are eschewed in favor of full PORT writes via the
    // OUT or ST instructions. It relies on two facts: that peripheral
    // functions (such as PWM) take precedence on output pins, so our PORT-
    // wide writes won't interfere, and that interrupts are globally disabled
    // while data is being issued to the LEDs, so no other code will be
    // accessing the PORT. The code takes an initial 'snapshot' of the PORT
    // state, computes 'pin high' and 'pin low' values, and writes these back
    // to the PORT register as needed.

#if defined(__arm__)

    // ARM MCUs -- Teensy 3.0, 3.1, LC, Arduino Due, RP2040 -------------------

#if defined(TEENSYDUINO) &&                                                  \
    defined(KINETISK) // Teensy 3.0, 3.1, 3.2, 3.5, 3.6
#define CYCLES_800_T0H (F_CPU / 4000000)
#define CYCLES_800_T1H (F_CPU / 1250000)
#define CYCLES_800 (F_CPU / 800000)
#define CYCLES_400_T0H (F_CPU / 2000000)
#define CYCLES_400_T1H (F_CPU / 833333)
#define CYCLES_400 (F_CPU / 400000)

  uint8_t *p = pixels, *end = p + numBytes, pix, mask;
  volatile uint8_t *set = portSetRegister(pin), *clr = portClearRegister(pin);
  uint32_t cyc;

  ARM_DEMCR |= ARM_DEMCR_TRCENA;
  ARM_DWT_CTRL |= ARM_DWT_CTRL_CYCCNTENA;

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    cyc = ARM_DWT_CYCCNT + CYCLES_800;
    while (p < end) {
      pix = *p++;
      for (mask = 0x80; mask; mask >>= 1) {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
          ;
        cyc = ARM_DWT_CYCCNT;
        *set = 1;
        if (pix & mask) {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T1H)
            ;
        } else {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T0H)
            ;
        }
        *clr = 1;
      }
    }
    while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
      ;
#if defined(NEO_KHZ400)
  } else { // 400 kHz bitstream
    cyc = ARM_DWT_CYCCNT + CYCLES_400;
    while (p < end) {
      pix = *p++;
      for (mask = 0x80; mask; mask >>= 1) {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_400)
          ;
        cyc = ARM_DWT_CYCCNT;
        *set = 1;
        if (pix & mask) {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_400_T1H)
            ;
        } else {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_400_T0H)
            ;
        }
        *clr = 1;
      }
    }
    while (ARM_DWT_CYCCNT - cyc < CYCLES_400)
      ;
  }
#endif // NEO_KHZ400

#elif defined(TEENSYDUINO) && (defined(__IMXRT1052__) || defined(__IMXRT1062__))
#define CYCLES_800_T0H (F_CPU_ACTUAL / 4000000)
#define CYCLES_800_T1H (F_CPU_ACTUAL / 1250000)
#define CYCLES_800 (F_CPU_ACTUAL / 800000)
#define CYCLES_400_T0H (F_CPU_ACTUAL / 2000000)
#define CYCLES_400_T1H (F_CPU_ACTUAL / 833333)
#define CYCLES_400 (F_CPU_ACTUAL / 400000)

  uint8_t *p = pixels, *end = p + numBytes, pix, mask;
  volatile uint32_t *set = portSetRegister(pin), *clr = portClearRegister(pin);
  uint32_t cyc, msk = digitalPinToBitMask(pin);

  ARM_DEMCR |= ARM_DEMCR_TRCENA;
  ARM_DWT_CTRL |= ARM_DWT_CTRL_CYCCNTENA;

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    cyc = ARM_DWT_CYCCNT + CYCLES_800;
    while (p < end) {
      pix = *p++;
      for (mask = 0x80; mask; mask >>= 1) {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
          ;
        cyc = ARM_DWT_CYCCNT;
        *set = msk;
        if (pix & mask) {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T1H)
            ;
        } else {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T0H)
            ;
        }
        *clr = msk;
      }
    }
    while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
      ;
#if defined(NEO_KHZ400)
  } else { // 400 kHz bitstream
    cyc = ARM_DWT_CYCCNT + CYCLES_400;
    while (p < end) {
      pix = *p++;
      for (mask = 0x80; mask; mask >>= 1) {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_400)
          ;
        cyc = ARM_DWT_CYCCNT;
        *set = msk;
        if (pix & mask) {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_400_T1H)
            ;
        } else {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_400_T0H)
            ;
        }
        *clr = msk;
      }
    }
    while (ARM_DWT_CYCCNT - cyc < CYCLES_400)
      ;
  }
#endif // NEO_KHZ400

#elif defined(TEENSYDUINO) && defined(__MKL26Z64__) // Teensy-LC

#if F_CPU == 48000000
  uint8_t *p = pixels, pix, count, dly, bitmask = digitalPinToBitMask(pin);
  volatile uint8_t *reg = portSetRegister(pin);
  uint32_t num = numBytes;
  asm volatile("L%=_begin:"
               "\n\t"
               "ldrb  %[pix], [%[p], #0]"
               "\n\t"
               "lsl   %[pix], #24"
               "\n\t"
               "movs  %[count], #7"
               "\n\t"
               "L%=_loop:"
               "\n\t"
               "lsl   %[pix], #1"
               "\n\t"
               "bcs   L%=_loop_one"
               "\n\t"
               "L%=_loop_zero:"
               "\n\t"
               "strb  %[bitmask], [%[reg], #0]"
               "\n\t"
               "movs  %[dly], #4"
               "\n\t"
               "L%=_loop_delay_T0H:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_loop_delay_T0H"
               "\n\t"
               "strb  %[bitmask], [%[reg], #4]"
               "\n\t"
               "movs  %[dly], #13"
               "\n\t"
               "L%=_loop_delay_T0L:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_loop_delay_T0L"
               "\n\t"
               "b     L%=_next"
               "\n\t"
               "L%=_loop_one:"
               "\n\t"
               "strb  %[bitmask], [%[reg], #0]"
               "\n\t"
               "movs  %[dly], #13"
               "\n\t"
               "L%=_loop_delay_T1H:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_loop_delay_T1H"
               "\n\t"
               "strb  %[bitmask], [%[reg], #4]"
               "\n\t"
               "movs  %[dly], #4"
               "\n\t"
               "L%=_loop_delay_T1L:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_loop_delay_T1L"
               "\n\t"
               "nop"
               "\n\t"
               "L%=_next:"
               "\n\t"
               "sub   %[count], #1"
               "\n\t"
               "bne   L%=_loop"
               "\n\t"
               "lsl   %[pix], #1"
               "\n\t"
               "bcs   L%=_last_one"
               "\n\t"
               "L%=_last_zero:"
               "\n\t"
               "strb  %[bitmask], [%[reg], #0]"
               "\n\t"
               "movs  %[dly], #4"
               "\n\t"
               "L%=_last_delay_T0H:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_last_delay_T0H"
               "\n\t"
               "strb  %[bitmask], [%[reg], #4]"
               "\n\t"
               "movs  %[dly], #10"
               "\n\t"
               "L%=_last_delay_T0L:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_last_delay_T0L"
               "\n\t"
               "b     L%=_repeat"
               "\n\t"
               "L%=_last_one:"
               "\n\t"
               "strb  %[bitmask], [%[reg], #0]"
               "\n\t"
               "movs  %[dly], #13"
               "\n\t"
               "L%=_last_delay_T1H:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_last_delay_T1H"
               "\n\t"
               "strb  %[bitmask], [%[reg], #4]"
               "\n\t"
               "movs  %[dly], #1"
               "\n\t"
               "L%=_last_delay_T1L:"
               "\n\t"
               "sub   %[dly], #1"
               "\n\t"
               "bne   L%=_last_delay_T1L"
               "\n\t"
               "nop"
               "\n\t"
               "L%=_repeat:"
               "\n\t"
               "add   %[p], #1"
               "\n\t"
               "sub   %[num], #1"
               "\n\t"
               "bne   L%=_begin"
               "\n\t"
               "L%=_done:"
               "\n\t"
               : [p] "+r"(p), [pix] "=&r"(pix), [count] "=&r"(count),
                 [dly] "=&r"(dly), [num] "+r"(num)
               : [bitmask] "r"(bitmask), [reg] "r"(reg));
#else
#error "Sorry, only 48 MHz is supported, please set Tools > CPU Speed to 48 MHz"
#endif // F_CPU == 48000000

  // Begin of support for nRF52 based boards  -------------------------

#elif defined(NRF52) || defined(NRF52_SERIES)
// [[[Begin of the Neopixel NRF52 EasyDMA implementation
//                                    by the Hackerspace San Salvador]]]
// This technique uses the PWM peripheral on the NRF52. The PWM uses the
// EasyDMA feature included on the chip. This technique loads the duty
// cycle configuration for each cycle when the PWM is enabled. For this
// to work we need to store a 16 bit configuration for each bit of the
// RGB(W) values in the pixel buffer.
// Comparator values for the PWM were hand picked and are guaranteed to
// be 100% organic to preserve freshness and high accuracy. Current
// parameters are:
//   * PWM Clock: 16Mhz
//   * Minimum step time: 62.5ns
//   * Time for zero in high (T0H): 0.31ms
//   * Time for one in high (T1H): 0.75ms
//   * Cycle time:  1.25us
//   * Frequency: 800Khz
// For 400Khz we just double the calculated times.
// ---------- BEGIN Constants for the EasyDMA implementation -----------
// The PWM starts the duty cycle in LOW. To start with HIGH we
// need to set the 15th bit on each register.

// WS2812 (rev A) timing is 0.35 and 0.7us
//#define MAGIC_T0H               5UL | (0x8000) // 0.3125us
//#define MAGIC_T1H              12UL | (0x8000) // 0.75us

// WS2812B (rev B) timing is 0.4 and 0.8 us
#define MAGIC_T0H 6UL | (0x8000) // 0.375us
#define MAGIC_T1H 13UL | (0x8000) // 0.8125us

// WS2811 (400 khz) timing is 0.5 and 1.2
#define MAGIC_T0H_400KHz 8UL | (0x8000) // 0.5us
#define MAGIC_T1H_400KHz 19UL | (0x8000) // 1.1875us

// For 400Khz, we double value of CTOPVAL
#define CTOPVAL 20UL // 1.25us
#define CTOPVAL_400KHz 40UL // 2.5us

// ---------- END Constants for the EasyDMA implementation -------------
//
// If there is no device available an alternative cycle-counter
// implementation is tried.
// The nRF52 runs with a fixed clock of 64Mhz. The alternative
// implementation is the same as the one used for the Teensy 3.0/1/2 but
// with the Nordic SDK HAL & registers syntax.
// The number of cycles was hand picked and is guaranteed to be 100%
// organic to preserve freshness and high accuracy.
// ---------- BEGIN Constants for cycle counter implementation ---------
#define CYCLES_800_T0H 18 // ~0.36 uS
#define CYCLES_800_T1H 41 // ~0.76 uS
#define CYCLES_800 71 // ~1.25 uS

#define CYCLES_400_T0H 26 // ~0.50 uS
#define CYCLES_400_T1H 70 // ~1.26 uS
#define CYCLES_400 156 // ~2.50 uS
  // ---------- END of Constants for cycle counter implementation --------

  // To support both the SoftDevice + Neopixels we use the EasyDMA
  // feature from the NRF25. However this technique implies to
  // generate a pattern and store it on the memory. The actual
  // memory used in bytes corresponds to the following formula:
  //              totalMem = numBytes*8*2+(2*2)
  // The two additional bytes at the end are needed to reset the
  // sequence.
  //
  // If there is not enough memory, we will fall back to cycle counter
  // using DWT
  uint32_t pattern_size =
      numBytes * 8 * sizeof(uint16_t) + 2 * sizeof(uint16_t);
  uint16_t *pixels_pattern = NULL;

  NRF_PWM_Type *pwm = NULL;

  // Try to find a free PWM device, which is not enabled
  // and has no connected pins
  NRF_PWM_Type *PWM[] = {
    NRF_PWM0,
    NRF_PWM1,
    NRF_PWM2
#if defined(NRF_PWM3)
    ,
    NRF_PWM3
#endif
  };

  for (unsigned int device = 0; device < (sizeof(PWM) / sizeof(PWM[0]));
       device++) {
    if ((PWM[device]->ENABLE == 0) &&
        (PWM[device]->PSEL.OUT[0] & PWM_PSEL_OUT_CONNECT_Msk) &&
        (PWM[device]->PSEL.OUT[1] & PWM_PSEL_OUT_CONNECT_Msk) &&
        (PWM[device]->PSEL.OUT[2] & PWM_PSEL_OUT_CONNECT_Msk) &&
        (PWM[device]->PSEL.OUT[3] & PWM_PSEL_OUT_CONNECT_Msk)) {
      pwm = PWM[device];
      break;
    }
  }

  // only malloc if there is PWM device available
  if (pwm != NULL) {
#if defined(ARDUINO_NRF52_ADAFRUIT) // use thread-safe malloc
    pixels_pattern = (uint16_t *)rtos_malloc(pattern_size);
#else
    pixels_pattern = (uint16_t *)malloc(pattern_size);
#endif
  }

  // Use the identified device to choose the implementation
  // If a PWM device is available use DMA
  if ((pixels_pattern != NULL) && (pwm != NULL)) {
    uint16_t pos = 0; // bit position

    for (uint16_t n = 0; n < numBytes; n++) {
      uint8_t pix = pixels[n];

      for (uint8_t mask = 0x80; mask > 0; mask >>= 1) {
#if defined(NEO_KHZ400)
        if (!is800KHz) {
          pixels_pattern[pos] =
              (pix & mask) ? MAGIC_T1H_400KHz : MAGIC_T0H_400KHz;
        } else
#endif
        {
          pixels_pattern[pos] = (pix & mask) ? MAGIC_T1H : MAGIC_T0H;
        }

        pos++;
      }
    }

    // Zero padding to indicate the end of que sequence
    pixels_pattern[pos++] = 0 | (0x8000); // Seq end
    pixels_pattern[pos++] = 0 | (0x8000); // Seq end

    // Set the wave mode to count UP
    pwm->MODE = (PWM_MODE_UPDOWN_Up << PWM_MODE_UPDOWN_Pos);

    // Set the PWM to use the 16MHz clock
    pwm->PRESCALER =
        (PWM_PRESCALER_PRESCALER_DIV_1 << PWM_PRESCALER_PRESCALER_Pos);

    // Setting of the maximum count
    // but keeping it on 16Mhz allows for more granularity just
    // in case someone wants to do more fine-tuning of the timing.
#if defined(NEO_KHZ400)
    if (!is800KHz) {
      pwm->COUNTERTOP = (CTOPVAL_400KHz << PWM_COUNTERTOP_COUNTERTOP_Pos);
    } else
#endif
    {
      pwm->COUNTERTOP = (CTOPVAL << PWM_COUNTERTOP_COUNTERTOP_Pos);
    }

    // Disable loops, we want the sequence to repeat only once
    pwm->LOOP = (PWM_LOOP_CNT_Disabled << PWM_LOOP_CNT_Pos);

    // On the "Common" setting the PWM uses the same pattern for the
    // for supported sequences. The pattern is stored on half-word
    // of 16bits
    pwm->DECODER = (PWM_DECODER_LOAD_Common << PWM_DECODER_LOAD_Pos) |
                   (PWM_DECODER_MODE_RefreshCount << PWM_DECODER_MODE_Pos);

    // Pointer to the memory storing the patter
    pwm->SEQ[0].PTR = (uint32_t)(pixels_pattern) << PWM_SEQ_PTR_PTR_Pos;

    // Calculation of the number of steps loaded from memory.
    pwm->SEQ[0].CNT = (pattern_size / sizeof(uint16_t)) << PWM_SEQ_CNT_CNT_Pos;

    // The following settings are ignored with the current config.
    pwm->SEQ[0].REFRESH = 0;
    pwm->SEQ[0].ENDDELAY = 0;

    // The Neopixel implementation is a blocking algorithm. DMA
    // allows for non-blocking operation. To "simulate" a blocking
    // operation we enable the interruption for the end of sequence
    // and block the execution thread until the event flag is set by
    // the peripheral.
    //    pwm->INTEN |= (PWM_INTEN_SEQEND0_Enabled<<PWM_INTEN_SEQEND0_Pos);

// PSEL must be configured before enabling PWM
#if defined(ARDUINO_ARCH_NRF52840)
    pwm->PSEL.OUT[0] = g_APinDescription[pin].name;
#else
    pwm->PSEL.OUT[0] = g_ADigitalPinMap[pin];
#endif

    // Enable the PWM
    pwm->ENABLE = 1;

    // After all of this and many hours of reading the documentation
    // we are ready to start the sequence...
    pwm->EVENTS_SEQEND[0] = 0;
    pwm->TASKS_SEQSTART[0] = 1;

    // But we have to wait for the flag to be set.
    while (!pwm->EVENTS_SEQEND[0]) {
#if defined(ARDUINO_NRF52_ADAFRUIT) || defined(ARDUINO_ARCH_NRF52840)
      yield();
#endif
    }

    // Before leave we clear the flag for the event.
    pwm->EVENTS_SEQEND[0] = 0;

    // We need to disable the device and disconnect
    // all the outputs before leave or the device will not
    // be selected on the next call.
    // TODO: Check if disabling the device causes performance issues.
    pwm->ENABLE = 0;

    pwm->PSEL.OUT[0] = 0xFFFFFFFFUL;

#if defined(ARDUINO_NRF52_ADAFRUIT) // use thread-safe free
    rtos_free(pixels_pattern);
#else
    free(pixels_pattern);
#endif
  } // End of DMA implementation
  // ---------------------------------------------------------------------
  else {
#ifndef ARDUINO_ARCH_NRF52840
// Fall back to DWT
#if defined(ARDUINO_NRF52_ADAFRUIT)
    // Bluefruit Feather 52 uses freeRTOS
    // Critical Section is used since it does not block SoftDevice execution
    taskENTER_CRITICAL();
#elif defined(NRF52_DISABLE_INT)
    // If you are using the Bluetooth SoftDevice we advise you to not disable
    // the interrupts. Disabling the interrupts even for short periods of time
    // causes the SoftDevice to stop working.
    // Disable the interrupts only in cases where you need high performance for
    // the LEDs and if you are not using the EasyDMA feature.
    __disable_irq();
#endif

    NRF_GPIO_Type *nrf_port = (NRF_GPIO_Type *)digitalPinToPort(pin);
    uint32_t pinMask = digitalPinToBitMask(pin);

    uint32_t CYCLES_X00 = CYCLES_800;
    uint32_t CYCLES_X00_T1H = CYCLES_800_T1H;
    uint32_t CYCLES_X00_T0H = CYCLES_800_T0H;

#if defined(NEO_KHZ400)
    if (!is800KHz) {
      CYCLES_X00 = CYCLES_400;
      CYCLES_X00_T1H = CYCLES_400_T1H;
      CYCLES_X00_T0H = CYCLES_400_T0H;
    }
#endif

    // Enable DWT in debug core
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

    // Tries to re-send the frame if is interrupted by the SoftDevice.
    while (1) {
      uint8_t *p = pixels;

      uint32_t cycStart = DWT->CYCCNT;
      uint32_t cyc = 0;

      for (uint16_t n = 0; n < numBytes; n++) {
        uint8_t pix = *p++;

        for (uint8_t mask = 0x80; mask; mask >>= 1) {
          while (DWT->CYCCNT - cyc < CYCLES_X00)
            ;
          cyc = DWT->CYCCNT;

          nrf_port->OUTSET |= pinMask;

          if (pix & mask) {
            while (DWT->CYCCNT - cyc < CYCLES_X00_T1H)
              ;
          } else {
            while (DWT->CYCCNT - cyc < CYCLES_X00_T0H)
              ;
          }

          nrf_port->OUTCLR |= pinMask;
        }
      }
      while (DWT->CYCCNT - cyc < CYCLES_X00)
        ;

      // If total time longer than 25%, resend the whole data.
      // Since we are likely to be interrupted by SoftDevice
      if ((DWT->CYCCNT - cycStart) < (8 * numBytes * ((CYCLES_X00 * 5) / 4))) {
        break;
      }

      // re-send need 300us delay
      delayMicroseconds(300);
    }

// Enable interrupts again
#if defined(ARDUINO_NRF52_ADAFRUIT)
    taskEXIT_CRITICAL();
#elif defined(NRF52_DISABLE_INT)
    __enable_irq();
#endif
#endif
  }
  // END of NRF52 implementation

#elif defined(__SAMD21E17A__) || defined(__SAMD21G18A__) || \
      defined(__SAMD21E18A__) || defined(__SAMD21J18A__) || \
      defined(__SAMD11C14A__) || defined(__SAMD21G17A__)
  // Arduino Zero, Gemma/Trinket M0, SODAQ Autonomo
  // and others
  // Tried this with a timer/counter, couldn't quite get adequate
  // resolution. So yay, you get a load of goofball NOPs...

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

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
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
#if defined(NEO_KHZ400)
  } else { // 400 KHz bitstream
    for (;;) {
      *set = pinMask;
      asm("nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;");
      if (p & bitMask) {
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop;");
        *clr = pinMask;
      } else {
        *clr = pinMask;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop;");
      }
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;");
      if (bitMask >>= 1) {
        asm("nop; nop; nop; nop; nop; nop; nop;");
      } else {
        if (ptr >= end)
          break;
        p = *ptr++;
        bitMask = 0x80;
      }
    }
  }
#endif

//----
#elif defined(XMC1100_XMC2GO) || defined(XMC1400_XMC2GO) || defined(XMC1400_Arduino_Kit) || defined(XMC1100_H_BRIDGE2GO) || defined(XMC1100_Boot_Kit)  || defined(XMC1300_Boot_Kit)

  // XMC1100/1200/1300 with ARM Cortex M0 are running with 32MHz, XMC1400 runs with 48MHz so may not work
  // Tried this with a timer/counter, couldn't quite get adequate
  // resolution.  So yay, you get a load of goofball NOPs...

  uint8_t  *ptr, *end, p, bitMask, portNum;
  uint32_t  pinMask;

  ptr     =  pixels;
  end     =  ptr + numBytes;
  p       = *ptr++;
  bitMask =  0x80;

  XMC_GPIO_PORT_t*  XMC_port = mapping_port_pin[ pin ].port;
  uint8_t  XMC_pin           = mapping_port_pin[ pin ].pin;

	uint32_t omrhigh = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_HIGH << XMC_pin;
	uint32_t omrlow  = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_LOW << XMC_pin;

#ifdef NEO_KHZ400 // 800 KHz check needed only if 400 KHz support enabled
  if(is800KHz) {
#endif
    for(;;) {
			XMC_port->OMR = omrhigh;
      asm("nop; nop; nop; nop;");
      if(p & bitMask) {
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop;");
			  XMC_port->OMR = omrlow;
      } else {
				XMC_port->OMR = omrlow;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop;");
      }
      if(bitMask >>= 1) {
        asm("nop; nop; nop; nop; nop;");
      } else {
        if(ptr >= end) break;
        p       = *ptr++;
        bitMask = 0x80;
      }
    }
#ifdef NEO_KHZ400 // untested code
  } else { // 400 KHz bitstream
    for(;;) {
      XMC_port->OMR = omrhigh;
      asm("nop; nop; nop; nop; nop;");
      if(p & bitMask) {
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop;");
        XMC_port->OMR = omrlow;
      } else {
        XMC_port->OMR = omrlow;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop;");
      }
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;");
      if(bitMask >>= 1) {
        asm("nop; nop; nop;");
      } else {
        if(ptr >= end) break;
        p       = *ptr++;
        bitMask = 0x80;
      }
    }
  }

#endif
//----

//----
#elif defined(XMC4700_Relax_Kit) || defined(XMC4800_Relax_Kit)

// XMC4700 and XMC4800 with ARM Cortex M4 are running with 144MHz
// Tried this with a timer/counter, couldn't quite get adequate
// resolution.  So yay, you get a load of goofball NOPs...

uint8_t  *ptr, *end, p, bitMask, portNum;
uint32_t  pinMask;

ptr     =  pixels;
end     =  ptr + numBytes;
p       = *ptr++;
bitMask =  0x80;

XMC_GPIO_PORT_t*   XMC_port = mapping_port_pin[ pin ].port;
uint8_t            XMC_pin  = mapping_port_pin[ pin ].pin;

uint32_t omrhigh = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_HIGH << XMC_pin;
uint32_t omrlow  = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_LOW << XMC_pin;

#ifdef NEO_KHZ400 // 800 KHz check needed only if 400 KHz support enabled
if(is800KHz) {
#endif

  for(;;) {
    XMC_port->OMR = omrhigh;
    asm("nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop;");
    if(p & bitMask) {
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;");
      XMC_port->OMR = omrlow;
    } else {
      XMC_port->OMR = omrlow;
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;");
    }
    if(bitMask >>= 1) {
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;");
    } else {
      if(ptr >= end) break;
      p       = *ptr++;
      bitMask = 0x80;
    }
  }


#ifdef NEO_KHZ400
  } else { // 400 KHz bitstream
    // ToDo!
  }
#endif
//----

#elif defined(__SAMD51__) // M4

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

  // SAMD51 overclock-compatible timing is only a mild abomination.
  // It uses SysTick for a consistent clock reference regardless of
  // optimization / cache settings.  That's the good news.  The bad news,
  // since SysTick->VAL is a volatile type it's slow to access...and then,
  // with the SysTick interval that Arduino sets up (1 ms), this would
  // require a subtract and MOD operation for gauging elapsed time, and
  // all taken in combination that lacks adequate temporal resolution
  // for NeoPixel timing.  So a kind of horrible thing is done here...
  // since interrupts are turned off anyway and it's generally accepted
  // by now that we're gonna lose track of time in the NeoPixel lib,
  // the SysTick timer is reconfigured for a period matching the NeoPixel
  // bit timing (either 800 or 400 KHz) and we watch SysTick->VAL very
  // closely (just a threshold, no subtract or MOD or anything) and that
  // seems to work just well enough.  When finished, the SysTick
  // peripheral is set back to its original state.

  uint32_t t0, t1, top, ticks, saveLoad = SysTick->LOAD, saveVal = SysTick->VAL;

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    top = (uint32_t)(F_CPU * 0.00000125);      // Bit hi + lo = 1.25 uS
    t0 = top - (uint32_t)(F_CPU * 0.00000040); // 0 = 0.4 uS hi
    t1 = top - (uint32_t)(F_CPU * 0.00000080); // 1 = 0.8 uS hi
#if defined(NEO_KHZ400)
  } else {                                     // 400 KHz bitstream
    top = (uint32_t)(F_CPU * 0.00000250);      // Bit hi + lo = 2.5 uS
    t0 = top - (uint32_t)(F_CPU * 0.00000050); // 0 = 0.5 uS hi
    t1 = top - (uint32_t)(F_CPU * 0.00000120); // 1 = 1.2 uS hi
  }
#endif

  SysTick->LOAD = top; // Config SysTick for NeoPixel bit freq
  SysTick->VAL = top;  // Set to start value (counts down)
  (void)SysTick->VAL;  // Dummy read helps sync up 1st bit

  for (;;) {
    *set = pinMask;                  // Set output high
    ticks = (p & bitMask) ? t1 : t0; // SysTick threshold,
    while (SysTick->VAL > ticks)
      ;                     // wait for it
    *clr = pinMask;         // Set output low
    if (!(bitMask >>= 1)) { // Next bit for this byte...done?
      if (ptr >= end)
        break;        // If last byte sent, exit loop
      p = *ptr++;     // Fetch next byte
      bitMask = 0x80; // Reset bitmask
    }
    while (SysTick->VAL <= ticks)
      ; // Wait for rollover to 'top'
  }

  SysTick->LOAD = saveLoad; // Restore SysTick rollover to 1 ms
  SysTick->VAL = saveVal;   // Restore SysTick value

#elif defined(ARDUINO_STM32_FEATHER) // FEATHER WICED (120MHz)

  // Tried this with a timer/counter, couldn't quite get adequate
  // resolution. So yay, you get a load of goofball NOPs...

  uint8_t *ptr, *end, p, bitMask;
  uint32_t pinMask;

  pinMask = BIT(PIN_MAP[pin].gpio_bit);
  ptr = pixels;
  end = ptr + numBytes;
  p = *ptr++;
  bitMask = 0x80;

  volatile uint16_t *set = &(PIN_MAP[pin].gpio_device->regs->BSRRL);
  volatile uint16_t *clr = &(PIN_MAP[pin].gpio_device->regs->BSRRH);

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    for (;;) {
      if (p & bitMask) { // ONE
        // High 800ns
        *set = pinMask;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop;");
        // Low 450ns
        *clr = pinMask;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop;");
      } else { // ZERO
        // High 400ns
        *set = pinMask;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop;");
        // Low 850ns
        *clr = pinMask;
        asm("nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop; nop; nop; nop; nop;"
            "nop; nop; nop; nop;");
      }
      if (bitMask >>= 1) {
        // Move on to the next pixel
        asm("nop;");
      } else {
        if (ptr >= end)
          break;
        p = *ptr++;
        bitMask = 0x80;
      }
    }
#if defined(NEO_KHZ400)
  } else { // 400 KHz bitstream
    // ToDo!
  }
#endif

#elif defined(TARGET_LPC1768)
  uint8_t *ptr, *end, p, bitMask;
  ptr = pixels;
  end = ptr + numBytes;
  p = *ptr++;
  bitMask = 0x80;

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    for (;;) {
      if (p & bitMask) {
        // data ONE high
        // min: 550 typ: 700 max: 5,500
        gpio_set(pin);
        time::delay_ns(550);
        // min: 450 typ: 600 max: 5,000
        gpio_clear(pin);
        time::delay_ns(450);
      } else {
        // data ZERO high
        // min: 200  typ: 350 max: 500
        gpio_set(pin);
        time::delay_ns(200);
        // data low
        // min: 450 typ: 600 max: 5,000
        gpio_clear(pin);
        time::delay_ns(450);
      }
      if (bitMask >>= 1) {
        // Move on to the next pixel
        asm("nop;");
      } else {
        if (ptr >= end)
          break;
        p = *ptr++;
        bitMask = 0x80;
      }
    }
#if defined(NEO_KHZ400)
  } else { // 400 KHz bitstream
    // ToDo!
  }
#endif

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    uint32_t top = (F_CPU / 800000);       // 1.25µs
    uint32_t t0 = top - (F_CPU / 2500000); // 0.4µs
    uint32_t t1 = top - (F_CPU / 1250000); // 0.8µs
    SysTick->LOAD = top - 1; // Config SysTick for NeoPixel bit freq
    SysTick->VAL = 0;        // Set to start value
    for (;;) {
      LL_GPIO_SetOutputPin(gpioPort, gpioPin);
      cyc = (pix & mask) ? t1 : t0;
      while (SysTick->VAL > cyc)
        ;
      LL_GPIO_ResetOutputPin(gpioPort, gpioPin);
      if (!(mask >>= 1)) {
        if (p >= end)
          break;
        pix = *p++;
        mask = 0x80;
      }
      while (SysTick->VAL <= cyc)
        ;
    }
#if defined(NEO_KHZ400)
  } else {                                 // 400 kHz bitstream
    uint32_t top = (F_CPU / 400000);       // 2.5µs
    uint32_t t0 = top - (F_CPU / 2000000); // 0.5µs
    uint32_t t1 = top - (F_CPU / 833333);  // 1.2µs
    SysTick->LOAD = top - 1; // Config SysTick for NeoPixel bit freq
    SysTick->VAL = 0;        // Set to start value
    for (;;) {
      LL_GPIO_SetOutputPin(gpioPort, gpioPin);
      cyc = (pix & mask) ? t1 : t0;
      while (SysTick->VAL > cyc)
        ;
      LL_GPIO_ResetOutputPin(gpioPort, gpioPin);
      if (!(mask >>= 1)) {
        if (p >= end)
          break;
        pix = *p++;
        mask = 0x80;
      }
      while (SysTick->VAL <= cyc)
        ;
    }
  }
#endif // NEO_KHZ400
  SysTick->LOAD = saveLoad; // Restore SysTick rollover to 1 ms
  SysTick->VAL = saveVal;   // Restore SysTick value

#elif defined(__SAM3X8E__) // Arduino Due

#define SCALE VARIANT_MCK / 2UL / 1000000UL
#define INST (2UL * F_CPU / VARIANT_MCK)
#define TIME_800_0 ((int)(0.40 * SCALE + 0.5) - (5 * INST))
#define TIME_800_1 ((int)(0.80 * SCALE + 0.5) - (5 * INST))
#define PERIOD_800 ((int)(1.25 * SCALE + 0.5) - (5 * INST))
#define TIME_400_0 ((int)(0.50 * SCALE + 0.5) - (5 * INST))
#define TIME_400_1 ((int)(1.20 * SCALE + 0.5) - (5 * INST))
#define PERIOD_400 ((int)(2.50 * SCALE + 0.5) - (5 * INST))

  int pinMask, time0, time1, period, t;
  Pio *port;
  volatile WoReg *portSet, *portClear, *timeValue, *timeReset;
  uint8_t *p, *end, pix, mask;

  pmc_set_writeprotect(false);
  pmc_enable_periph_clk((uint32_t)TC3_IRQn);
  TC_Configure(TC1, 0,
               TC_CMR_WAVE | TC_CMR_WAVSEL_UP | TC_CMR_TCCLKS_TIMER_CLOCK1);
  TC_Start(TC1, 0);

  pinMask = g_APinDescription[pin].ulPin;  // Don't 'optimize' these into
  port = g_APinDescription[pin].pPort;     // declarations above. Want to
  portSet = &(port->PIO_SODR);             // burn a few cycles after
  portClear = &(port->PIO_CODR);           // starting timer to minimize
  timeValue = &(TC1->TC_CHANNEL[0].TC_CV); // the initial 'while'.
  timeReset = &(TC1->TC_CHANNEL[0].TC_CCR);
  p = pixels;
  end = p + numBytes;
  pix = *p++;
  mask = 0x80;

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    time0 = TIME_800_0;
    time1 = TIME_800_1;
    period = PERIOD_800;
#if defined(NEO_KHZ400)
  } else { // 400 KHz bitstream
    time0 = TIME_400_0;
    time1 = TIME_400_1;
    period = PERIOD_400;
  }
#endif

  for (t = time0;; t = time0) {
    if (pix & mask)
      t = time1;
    while (*timeValue < (unsigned)period)
      ;
    *portSet = pinMask;
    *timeReset = TC_CCR_CLKEN | TC_CCR_SWTRG;
    while (*timeValue < (unsigned)t)
      ;
    *portClear = pinMask;
    if (!(mask >>= 1)) { // This 'inside-out' loop logic utilizes
      if (p >= end)
        break; // idle time to minimize inter-byte delays.
      pix = *p++;
      mask = 0x80;
    }
  }
  while (*timeValue < (unsigned)period)
    ; // Wait for last bit
  TC_Stop(TC1, 0);


// RENESAS including Arduino UNO R4 + STM32H7 Arduino Portenta H7 (Dual Core M7+M4) / Arduino Giga R1
#elif defined(ARDUINO_ARCH_RENESAS) || defined(ARDUINO_ARCH_RENESAS_UNO) || defined(ARDUINO_ARCH_RENESAS_PORTENTA) || defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)

// Definition for a single channel clockless controller for RA4M1 (Cortex M4)
// See clockless.h for detailed info on how the template parameters are used.
#define ARM_DEMCR               (*(volatile uint32_t *)0xE000EDFC) // Debug Exception and Monitor Control
#define ARM_DEMCR_TRCENA                (1 << 24)        // Enable debugging & monitoring blocks
#define ARM_DWT_CTRL            (*(volatile uint32_t *)0xE0001000) // DWT control register
#define ARM_DWT_CTRL_CYCCNTENA          (1 << 0)                // Enable cycle count
#define ARM_DWT_CYCCNT          (*(volatile uint32_t *)0xE0001004) // Cycle count register

#if defined(ARDUINO_PORTENTA_H7_M7) || (defined(ARDUINO_ARCH_MBED_GIGA) && defined(TARGET_M7))
#define F_CPU 480000000
#elif defined(ARDUINO_PORTENTA_H7_M4) || (defined(ARDUINO_ARCH_MBED_GIGA) && defined(TARGET_M4)) 
#define F_CPU 240000000
#else
#define F_CPU 48000000
#endif
#define CYCLES_800_T0H (F_CPU / 4000000)
#define CYCLES_800_T1H (F_CPU / 1250000)
#define CYCLES_800 (F_CPU / 800000)
#define CYCLES_400_T0H (F_CPU / 2000000)
#define CYCLES_400_T1H (F_CPU / 833333)
#define CYCLES_400 (F_CPU / 400000)

  uint8_t *p = pixels, *end = p + numBytes, pix, mask;

// --- Platform-specific Pin Setup ---
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
  // Convert the Arduino pin number to an mbed PinName.
  mbed::DigitalOut dout(digitalPinToPinName(pin));
#else
  bsp_io_port_pin_t io_pin = g_pin_cfg[pin].pin;
  // Macro to calculate the port base address for the given pin
  #define PIN_IO_PORT_ADDR(pn)      (R_PORT0 + ((uint32_t) (R_PORT1 - R_PORT0) * ((pn) >> 8u)))

  volatile uint16_t *set = &(PIN_IO_PORT_ADDR(io_pin)->POSR);
  volatile uint16_t *clr = &(PIN_IO_PORT_ADDR(io_pin)->PORR);
  uint16_t msk = (1U << (io_pin & 0xFF));
#endif

  uint32_t cyc;

  // Enable the cycle counter: ARM registers for precise timing.
  ARM_DEMCR |= ARM_DEMCR_TRCENA;
  ARM_DWT_CTRL |= ARM_DWT_CTRL_CYCCNTENA;

#if defined(NEO_KHZ400) // 800 KHz check needed only if 400 KHz support enabled
  if (is800KHz) {
#endif
    cyc = ARM_DWT_CYCCNT + CYCLES_800;
    while (p < end) {
      pix = *p++;
      for (mask = 0x80; mask; mask >>= 1) {
        // Wait until the beginning of the next bit period.
        while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
          ;
        cyc = ARM_DWT_CYCCNT;
        // Set the pin high:
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
        dout = 1;
#else
        *set = msk;
#endif
        // Keep the pin high for T1H or T0H depending on the data bit:
        if (pix & mask) {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T1H)
            ;
        } else {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T0H)
            ;
        }
        // Set the pin low:
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
        dout = 0;
#else
        *clr = msk;
#endif
      }
    }
    // Ensure the final low state lasts the full period.
    while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
      ;
#if defined(NEO_KHZ400)
  } else { // 400 kHz bitstream
    cyc = ARM_DWT_CYCCNT + CYCLES_400;
    while (p < end) {
      pix = *p++;
      for (mask = 0x80; mask; mask >>= 1) {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_400)
          ;
        cyc = ARM_DWT_CYCCNT;
        // Set the pin high:
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
        dout = 1;
#else
        *set = msk;
#endif
        if (pix & mask) {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_400_T1H)
            ;
        } else {
          while (ARM_DWT_CYCCNT - cyc < CYCLES_400_T0H)
            ;
        }
        // Set the pin low:
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
        dout = 0;
#else
        *clr = msk;
#endif
      }
    }
    // Ensure the final low state lasts the full period.
    while (ARM_DWT_CYCCNT - cyc < CYCLES_400)
      ;
  }
#endif // NEO_KHZ400

#endif // ARM

  // END ARM ----------------------------------------------------------------

#else
#error Architecture not supported
#endif

  // END ARCHITECTURE SELECT ------------------------------------------------

  endTime = micros(); // Save EOD time for latch on next call
}

/*!
  @brief   Set/change the NeoPixel output pin number. Previous pin,
           if any, is set to INPUT and the new pin is set to OUTPUT.
  @param   p  Arduino pin number (-1 = no pin).
*/
void Adafruit_NeoPixel::setPin(int16_t p) {
  if (begun && (pin >= 0))
    pinMode(pin, INPUT); // Disable existing out pin
  pin = p;
  if (begun) {
    pinMode(p, OUTPUT);
    digitalWrite(p, LOW);
  }

#if defined(ARDUINO_ARCH_CH32)
  PinName const pin_name = digitalPinToPinName(pin);
  gpioPort = get_GPIO_Port(CH_PORT(pin_name));
  gpioPin = CH_GPIO_PIN(pin_name);
  #if defined (CH32V20x_D6)
  if (gpioPort == GPIOC && ((*(volatile uint32_t*)0x40022030) & 0x0F000000) == 0) {
    gpioPin = gpioPin >> 13;
  }
  #endif
#endif
}

/*!
  @brief   Set a pixel's color using separate red, green and blue
           components. If using RGBW pixels, white will be set to 0.
  @param   n  Pixel index, starting from 0.
  @param   r  Red brightness, 0 = minimum (off), 255 = maximum.
  @param   g  Green brightness, 0 = minimum (off), 255 = maximum.
  @param   b  Blue brightness, 0 = minimum (off), 255 = maximum.
*/
void Adafruit_NeoPixel::setPixelColor(uint16_t n, uint8_t r, uint8_t g,
                                      uint8_t b) {

  if (n < numLEDs) {
    if (brightness) { // See notes in setBrightness()
      r = (r * brightness) >> 8;
      g = (g * brightness) >> 8;
      b = (b * brightness) >> 8;
    }
    uint8_t *p;
    if (wOffset == rOffset) { // Is an RGB-type strip
      p = &pixels[n * 3];     // 3 bytes per pixel
    } else {                  // Is a WRGB-type strip
      p = &pixels[n * 4];     // 4 bytes per pixel
      p[wOffset] = 0;         // But only R,G,B passed -- set W to 0
    }
    p[rOffset] = r; // R,G,B always stored
    p[gOffset] = g;
    p[bOffset] = b;
  }
}

/*!
  @brief   Set a pixel's color using separate red, green, blue and white
           components (for RGBW NeoPixels only).
  @param   n  Pixel index, starting from 0.
  @param   r  Red brightness, 0 = minimum (off), 255 = maximum.
  @param   g  Green brightness, 0 = minimum (off), 255 = maximum.
  @param   b  Blue brightness, 0 = minimum (off), 255 = maximum.
  @param   w  White brightness, 0 = minimum (off), 255 = maximum, ignored
              if using RGB pixels.
*/
void Adafruit_NeoPixel::setPixelColor(uint16_t n, uint8_t r, uint8_t g,
                                      uint8_t b, uint8_t w) {

  if (n < numLEDs) {
    if (brightness) { // See notes in setBrightness()
      r = (r * brightness) >> 8;
      g = (g * brightness) >> 8;
      b = (b * brightness) >> 8;
      w = (w * brightness) >> 8;
    }
    uint8_t *p;
    if (wOffset == rOffset) { // Is an RGB-type strip
      p = &pixels[n * 3];     // 3 bytes per pixel (ignore W)
    } else {                  // Is a WRGB-type strip
      p = &pixels[n * 4];     // 4 bytes per pixel
      p[wOffset] = w;         // Store W
    }
    p[rOffset] = r; // Store R,G,B
    p[gOffset] = g;
    p[bOffset] = b;
  }
}

/*!
  @brief   Set a pixel's color using a 32-bit 'packed' RGB or RGBW value.
  @param   n  Pixel index, starting from 0.
  @param   c  32-bit color value. Most significant byte is white (for RGBW
              pixels) or ignored (for RGB pixels), next is red, then green,
              and least significant byte is blue.
*/
void Adafruit_NeoPixel::setPixelColor(uint16_t n, uint32_t c) {
  if (n < numLEDs) {
    uint8_t *p, r = (uint8_t)(c >> 16), g = (uint8_t)(c >> 8), b = (uint8_t)c;
    if (brightness) { // See notes in setBrightness()
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
  @brief   Fill all or part of the NeoPixel strip with a color.
  @param   c      32-bit color value. Most significant byte is white (for
                  RGBW pixels) or ignored (for RGB pixels), next is red,
                  then green, and least significant byte is blue. If all
                  arguments are unspecified, this will be 0 (off).
  @param   first  Index of first pixel to fill, starting from 0. Must be
                  in-bounds, no clipping is performed. 0 if unspecified.
  @param   count  Number of pixels to fill, as a positive value. Passing
                  0 or leaving unspecified will fill to end of strip.
*/
void Adafruit_NeoPixel::fill(uint32_t c, uint16_t first, uint16_t count) {
  uint16_t i, end;

  if (first >= numLEDs) {
    return; // If first LED is past end of strip, nothing to do
  }

  // Calculate the index ONE AFTER the last pixel to fill
  if (count == 0) {
    // Fill to end of strip
    end = numLEDs;
  } else {
    // Ensure that the loop won't go past the last pixel
    end = first + count;
    if (end > numLEDs)
      end = numLEDs;
  }

  for (i = first; i < end; i++) {
    this->setPixelColor(i, c);
  }
}

/*!
  @brief   Query the color of a previously-set pixel.
  @param   n  Index of pixel to read (0 = first).
  @return  'Packed' 32-bit RGB or WRGB value. Most significant byte is white
           (for RGBW pixels) or 0 (for RGB pixels), next is red, then green,
           and least significant byte is blue.
  @note    If the strip brightness has been changed from the default value
           of 255, the color read from a pixel may not exactly match what
           was previously written with one of the setPixelColor() functions.
           This gets more pronounced at lower brightness levels.
*/
uint32_t Adafruit_NeoPixel::getPixelColor(uint16_t n) const {
  if (n >= numLEDs)
    return 0; // Out of bounds, return no color.

  uint8_t *p;

  if (wOffset == rOffset) { // Is RGB-type device
    p = &pixels[n * 3];
    if (brightness) {
      // Stored color was decimated by setBrightness(). Returned value
      // attempts to scale back to an approximation of the original 24-bit
      // value used when setting the pixel color, but there will always be
      // some error -- those bits are simply gone. Issue is most
      // pronounced at low brightness levels.
      return (((uint32_t)(p[rOffset] << 8) / brightness) << 16) |
             (((uint32_t)(p[gOffset] << 8) / brightness) << 8) |
             ((uint32_t)(p[bOffset] << 8) / brightness);
    } else {
      // No brightness adjustment has been made -- return 'raw' color
      return ((uint32_t)p[rOffset] << 16) | ((uint32_t)p[gOffset] << 8) |
             (uint32_t)p[bOffset];
    }
  } else { // Is RGBW-type device
    p = &pixels[n * 4];
    if (brightness) { // Return scaled color
      return (((uint32_t)(p[wOffset] << 8) / brightness) << 24) |
             (((uint32_t)(p[rOffset] << 8) / brightness) << 16) |
             (((uint32_t)(p[gOffset] << 8) / brightness) << 8) |
             ((uint32_t)(p[bOffset] << 8) / brightness);
    } else { // Return raw color
      return ((uint32_t)p[wOffset] << 24) | ((uint32_t)p[rOffset] << 16) |
             ((uint32_t)p[gOffset] << 8) | (uint32_t)p[bOffset];
    }
  }
}

/*!
  @brief   Adjust output brightness. Does not immediately affect what's
           currently displayed on the LEDs. The next call to show() will
           refresh the LEDs at this level.
  @param   b  Brightness setting, 0=minimum (off), 255=brightest.
  @note    This was intended for one-time use in one's setup() function,
           not as an animation effect in itself. Because of the way this
           library "pre-multiplies" LED colors in RAM, changing the
           brightness is often a "lossy" operation -- what you write to
           pixels isn't necessary the same as what you'll read back.
           Repeated brightness changes using this function exacerbate the
           problem. Smart programs therefore treat the strip as a
           write-only resource, maintaining their own state to render each
           frame of an animation, not relying on read-modify-write.
*/
void Adafruit_NeoPixel::setBrightness(uint8_t b) {
  // Stored brightness value is different than what's passed.
  // This simplifies the actual scaling math later, allowing a fast
  // 8x8-bit multiply and taking the MSB. 'brightness' is a uint8_t,
  // adding 1 here may (intentionally) roll over...so 0 = max brightness
  // (color values are interpreted literally; no scaling), 1 = min
  // brightness (off), 255 = just below max brightness.
  uint8_t newBrightness = b + 1;
  if (newBrightness != brightness) { // Compare against prior value
    // Brightness has changed -- re-scale existing data in RAM,
    // This process is potentially "lossy," especially when increasing
    // brightness. The tight timing in the WS2811/WS2812 code means there
    // aren't enough free cycles to perform this scaling on the fly as data
    // is issued. So we make a pass through the existing color data in RAM
    // and scale it (subsequent graphics commands also work at this
    // brightness level). If there's a significant step up in brightness,
    // the limited number of steps (quantization) in the old data will be
    // quite visible in the re-scaled version. For a non-destructive
    // change, you'll need to re-render the full strip data. C'est la vie.
    uint8_t c, *ptr = pixels,
               oldBrightness = brightness - 1; // De-wrap old brightness value
    uint16_t scale;
    if (oldBrightness == 0)
      scale = 0; // Avoid /0
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
  @brief   Retrieve the last-set brightness value for the strip.
  @return  Brightness value: 0 = minimum (off), 255 = maximum.
*/
uint8_t Adafruit_NeoPixel::getBrightness(void) const { return brightness - 1; }

/*!
  @brief   Fill the whole NeoPixel strip with 0 / black / off.
*/
void Adafruit_NeoPixel::clear(void) { memset(pixels, 0, numBytes); }
