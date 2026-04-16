#include "Adafruit_NeoPixel.h"

#if defined(ARDUINO_ARCH_MBED)
#include "mbed.h"
#endif

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


#if defined(ARDUINO_ARCH_CH32)

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
  if (!is800KHz) return;

  volatile uint32_t* set = &ch_port->BSHR;
  volatile uint32_t* clr = &ch_port->BCR;

  uint8_t* ptr = pixels;
  uint8_t* end = ptr + numBytes;
  uint8_t p = *ptr++;
  uint8_t bitMask = 0x80;

  while (1) {
    if (p & bitMask) { // ONE
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
      asm("nop;");
    } else {
      if (ptr >= end) break;
      p = *ptr++;
      bitMask = 0x80;
    }
  }
}
#endif

/*!
  @brief   Transmit pixel data in RAM to NeoPixels.
*/
void Adafruit_NeoPixel::show(void) {

  if (!pixels)
    return;

  while (!canShow())
    ;

#if defined(__arm__)

#if defined(TEENSYDUINO) && defined(KINETISK)
#define CYCLES_800_T0H (F_CPU / 4000000)
#define CYCLES_800_T1H (F_CPU / 1250000)
#define CYCLES_800 (F_CPU / 800000)

  uint8_t *p = pixels, *end = p + numBytes, pix, mask;
  volatile uint8_t *set = portSetRegister(pin), *clr = portClearRegister(pin);
  uint32_t cyc;

  ARM_DEMCR |= ARM_DEMCR_TRCENA;
  ARM_DWT_CTRL |= ARM_DWT_CTRL_CYCCNTENA;

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

#elif defined(TEENSYDUINO) && (defined(__IMXRT1052__) || defined(__IMXRT1062__))
#define CYCLES_800_T0H (F_CPU_ACTUAL / 4000000)
#define CYCLES_800_T1H (F_CPU_ACTUAL / 1250000)
#define CYCLES_800 (F_CPU_ACTUAL / 800000)

  uint8_t *p = pixels, *end = p + numBytes, pix, mask;
  volatile uint32_t *set = portSetRegister(pin), *clr = portClearRegister(pin);
  uint32_t cyc, msk = digitalPinToBitMask(pin);

  ARM_DEMCR |= ARM_DEMCR_TRCENA;
  ARM_DWT_CTRL |= ARM_DWT_CTRL_CYCCNTENA;

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

#elif defined(TEENSYDUINO) && defined(__MKL26Z64__)

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
#endif

#elif defined(NRF52) || defined(NRF52_SERIES)
#define MAGIC_T0H 6UL | (0x8000)
#define MAGIC_T1H 13UL | (0x8000)
#define CTOPVAL 20UL
#define CYCLES_800_T0H 18
#define CYCLES_800_T1H 41
#define CYCLES_800 71

  uint32_t pattern_size =
      numBytes * 8 * sizeof(uint16_t) + 2 * sizeof(uint16_t);
  uint16_t *pixels_pattern = NULL;

  NRF_PWM_Type *pwm = NULL;

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

  if (pwm != NULL) {
#if defined(ARDUINO_NRF52_ADAFRUIT)
    pixels_pattern = (uint16_t *)rtos_malloc(pattern_size);
#else
    pixels_pattern = (uint16_t *)malloc(pattern_size);
#endif
  }

  if ((pixels_pattern != NULL) && (pwm != NULL)) {
    uint16_t pos = 0;

    for (uint16_t n = 0; n < numBytes; n++) {
      uint8_t pix = pixels[n];
      for (uint8_t mask = 0x80; mask > 0; mask >>= 1) {
        pixels_pattern[pos] = (pix & mask) ? MAGIC_T1H : MAGIC_T0H;
        pos++;
      }
    }

    pixels_pattern[pos++] = 0 | (0x8000);
    pixels_pattern[pos++] = 0 | (0x8000);

    pwm->MODE = (PWM_MODE_UPDOWN_Up << PWM_MODE_UPDOWN_Pos);
    pwm->PRESCALER = (PWM_PRESCALER_PRESCALER_DIV_1 << PWM_PRESCALER_PRESCALER_Pos);
    pwm->COUNTERTOP = (CTOPVAL << PWM_COUNTERTOP_COUNTERTOP_Pos);
    pwm->LOOP = (PWM_LOOP_CNT_Disabled << PWM_LOOP_CNT_Pos);
    pwm->DECODER = (PWM_DECODER_LOAD_Common << PWM_DECODER_LOAD_Pos) |
                   (PWM_DECODER_MODE_RefreshCount << PWM_DECODER_MODE_Pos);
    pwm->SEQ[0].PTR = (uint32_t)(pixels_pattern) << PWM_SEQ_PTR_PTR_Pos;
    pwm->SEQ[0].CNT = (pattern_size / sizeof(uint16_t)) << PWM_SEQ_CNT_CNT_Pos;
    pwm->SEQ[0].REFRESH = 0;
    pwm->SEQ[0].ENDDELAY = 0;

#if defined(ARDUINO_ARCH_NRF52840)
    pwm->PSEL.OUT[0] = g_APinDescription[pin].name;
#else
    pwm->PSEL.OUT[0] = g_ADigitalPinMap[pin];
#endif

    pwm->ENABLE = 1;
    pwm->EVENTS_SEQEND[0] = 0;
    pwm->TASKS_SEQSTART[0] = 1;

    while (!pwm->EVENTS_SEQEND[0]) {
#if defined(ARDUINO_NRF52_ADAFRUIT) || defined(ARDUINO_ARCH_NRF52840)
      yield();
#endif
    }

    pwm->EVENTS_SEQEND[0] = 0;
    pwm->ENABLE = 0;
    pwm->PSEL.OUT[0] = 0xFFFFFFFFUL;

#if defined(ARDUINO_NRF52_ADAFRUIT)
    rtos_free(pixels_pattern);
#else
    free(pixels_pattern);
#endif
  } else {
#ifndef ARDUINO_ARCH_NRF52840
#if defined(ARDUINO_NRF52_ADAFRUIT)
    taskENTER_CRITICAL();
#elif defined(NRF52_DISABLE_INT)
    __disable_irq();
#endif

    NRF_GPIO_Type *nrf_port = (NRF_GPIO_Type *)digitalPinToPort(pin);
    uint32_t pinMask = digitalPinToBitMask(pin);

    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

    while (1) {
      uint8_t *p = pixels;
      uint32_t cycStart = DWT->CYCCNT;
      uint32_t cyc = 0;

      for (uint16_t n = 0; n < numBytes; n++) {
        uint8_t pix = *p++;
        for (uint8_t mask = 0x80; mask; mask >>= 1) {
          while (DWT->CYCCNT - cyc < CYCLES_800)
            ;
          cyc = DWT->CYCCNT;
          nrf_port->OUTSET |= pinMask;
          if (pix & mask) {
            while (DWT->CYCCNT - cyc < CYCLES_800_T1H)
              ;
          } else {
            while (DWT->CYCCNT - cyc < CYCLES_800_T0H)
              ;
          }
          nrf_port->OUTCLR |= pinMask;
        }
      }
      while (DWT->CYCCNT - cyc < CYCLES_800)
        ;

      if ((DWT->CYCCNT - cycStart) < (8 * numBytes * ((CYCLES_800 * 5) / 4))) {
        break;
      }
      delayMicroseconds(300);
    }

#if defined(ARDUINO_NRF52_ADAFRUIT)
    taskEXIT_CRITICAL();
#elif defined(NRF52_DISABLE_INT)
    __enable_irq();
#endif
#endif
  }

#elif defined(__SAMD21E17A__) || defined(__SAMD21G18A__) || \
      defined(__SAMD21E18A__) || defined(__SAMD21J18A__) || \
      defined(__SAMD11C14A__) || defined(__SAMD21G17A__)

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

#elif defined(XMC1100_XMC2GO) || defined(XMC1400_XMC2GO) || defined(XMC1400_Arduino_Kit) || defined(XMC1100_H_BRIDGE2GO) || defined(XMC1100_Boot_Kit) || defined(XMC1300_Boot_Kit)

  uint8_t *ptr, *end, p, bitMask, portNum;
  uint32_t pinMask;

  ptr     =  pixels;
  end     =  ptr + numBytes;
  p       = *ptr++;
  bitMask =  0x80;

  XMC_GPIO_PORT_t* XMC_port = mapping_port_pin[pin].port;
  uint8_t XMC_pin            = mapping_port_pin[pin].pin;
  uint32_t omrhigh = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_HIGH << XMC_pin;
  uint32_t omrlow  = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_LOW << XMC_pin;

  for (;;) {
    XMC_port->OMR = omrhigh;
    asm("nop; nop; nop; nop;");
    if (p & bitMask) {
      asm("nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;");
      XMC_port->OMR = omrlow;
    } else {
      XMC_port->OMR = omrlow;
      asm("nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;");
    }
    if (bitMask >>= 1) {
      asm("nop; nop; nop; nop; nop;");
    } else {
      if (ptr >= end) break;
      p       = *ptr++;
      bitMask = 0x80;
    }
  }

#elif defined(XMC4700_Relax_Kit) || defined(XMC4800_Relax_Kit)

  uint8_t *ptr, *end, p, bitMask, portNum;
  uint32_t pinMask;

  ptr     =  pixels;
  end     =  ptr + numBytes;
  p       = *ptr++;
  bitMask =  0x80;

  XMC_GPIO_PORT_t* XMC_port = mapping_port_pin[pin].port;
  uint8_t XMC_pin            = mapping_port_pin[pin].pin;
  uint32_t omrhigh = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_HIGH << XMC_pin;
  uint32_t omrlow  = (uint32_t)XMC_GPIO_OUTPUT_LEVEL_LOW << XMC_pin;

  for (;;) {
    XMC_port->OMR = omrhigh;
    asm("nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop; nop; nop; nop; nop;"
        "nop; nop; nop; nop;");
    if (p & bitMask) {
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
    if (bitMask >>= 1) {
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
      if (ptr >= end) break;
      p       = *ptr++;
      bitMask = 0x80;
    }
  }

#elif defined(__SAMD51__)

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

  uint32_t t0, t1, top, ticks, saveLoad = SysTick->LOAD, saveVal = SysTick->VAL;

  top = (uint32_t)(F_CPU * 0.00000125);
  t0  = top - (uint32_t)(F_CPU * 0.00000040);
  t1  = top - (uint32_t)(F_CPU * 0.00000080);

  SysTick->LOAD = top;
  SysTick->VAL  = top;
  (void)SysTick->VAL;

  for (;;) {
    *set = pinMask;
    ticks = (p & bitMask) ? t1 : t0;
    while (SysTick->VAL > ticks)
      ;
    *clr = pinMask;
    if (!(bitMask >>= 1)) {
      if (ptr >= end) break;
      p = *ptr++;
      bitMask = 0x80;
    }
    while (SysTick->VAL <= ticks)
      ;
  }

  SysTick->LOAD = saveLoad;
  SysTick->VAL  = saveVal;

#elif defined(ARDUINO_STM32_FEATHER)

  uint8_t *ptr, *end, p, bitMask;
  uint32_t pinMask;

  pinMask = BIT(PIN_MAP[pin].gpio_bit);
  ptr = pixels;
  end = ptr + numBytes;
  p = *ptr++;
  bitMask = 0x80;

  volatile uint16_t *set = &(PIN_MAP[pin].gpio_device->regs->BSRRL);
  volatile uint16_t *clr = &(PIN_MAP[pin].gpio_device->regs->BSRRH);

  for (;;) {
    if (p & bitMask) {
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
      *clr = pinMask;
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop;");
    } else {
      *set = pinMask;
      asm("nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop; nop; nop; nop; nop; nop; nop; nop;"
          "nop;");
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
      asm("nop;");
    } else {
      if (ptr >= end) break;
      p = *ptr++;
      bitMask = 0x80;
    }
  }

#elif defined(TARGET_LPC1768)
  uint8_t *ptr, *end, p, bitMask;
  ptr = pixels;
  end = ptr + numBytes;
  p = *ptr++;
  bitMask = 0x80;

  for (;;) {
    if (p & bitMask) {
      gpio_set(pin);
      time::delay_ns(550);
      gpio_clear(pin);
      time::delay_ns(450);
    } else {
      gpio_set(pin);
      time::delay_ns(200);
      gpio_clear(pin);
      time::delay_ns(450);
    }
    if (bitMask >>= 1) {
      asm("nop;");
    } else {
      if (ptr >= end) break;
      p = *ptr++;
      bitMask = 0x80;
    }
  }

#elif defined(__SAM3X8E__)

#define SCALE VARIANT_MCK / 2UL / 1000000UL
#define INST (2UL * F_CPU / VARIANT_MCK)
#define TIME_800_0 ((int)(0.40 * SCALE + 0.5) - (5 * INST))
#define TIME_800_1 ((int)(0.80 * SCALE + 0.5) - (5 * INST))
#define PERIOD_800 ((int)(1.25 * SCALE + 0.5) - (5 * INST))

  int pinMask, time0, time1, period, t;
  Pio *port;
  volatile WoReg *portSet, *portClear, *timeValue, *timeReset;
  uint8_t *p, *end, pix, mask;

  pmc_set_writeprotect(false);
  pmc_enable_periph_clk((uint32_t)TC3_IRQn);
  TC_Configure(TC1, 0,
               TC_CMR_WAVE | TC_CMR_WAVSEL_UP | TC_CMR_TCCLKS_TIMER_CLOCK1);
  TC_Start(TC1, 0);

  pinMask  = g_APinDescription[pin].ulPin;
  port     = g_APinDescription[pin].pPort;
  portSet  = &(port->PIO_SODR);
  portClear = &(port->PIO_CODR);
  timeValue = &(TC1->TC_CHANNEL[0].TC_CV);
  timeReset = &(TC1->TC_CHANNEL[0].TC_CCR);
  p    = pixels;
  end  = p + numBytes;
  pix  = *p++;
  mask = 0x80;
  time0  = TIME_800_0;
  time1  = TIME_800_1;
  period = PERIOD_800;

  for (t = time0;; t = time0) {
    if (pix & mask) t = time1;
    while (*timeValue < (unsigned)period)
      ;
    *portSet = pinMask;
    *timeReset = TC_CCR_CLKEN | TC_CCR_SWTRG;
    while (*timeValue < (unsigned)t)
      ;
    *portClear = pinMask;
    if (!(mask >>= 1)) {
      if (p >= end) break;
      pix = *p++;
      mask = 0x80;
    }
  }
  while (*timeValue < (unsigned)period)
    ;
  TC_Stop(TC1, 0);

#elif defined(ARDUINO_ARCH_RENESAS) || defined(ARDUINO_ARCH_RENESAS_UNO) || defined(ARDUINO_ARCH_RENESAS_PORTENTA) || defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)

#define ARM_DEMCR               (*(volatile uint32_t *)0xE000EDFC)
#define ARM_DEMCR_TRCENA                (1 << 24)
#define ARM_DWT_CTRL            (*(volatile uint32_t *)0xE0001000)
#define ARM_DWT_CTRL_CYCCNTENA          (1 << 0)
#define ARM_DWT_CYCCNT          (*(volatile uint32_t *)0xE0001004)

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

  uint8_t *p = pixels, *end = p + numBytes, pix, mask;

#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
  mbed::DigitalOut dout(digitalPinToPinName(pin));
#else
  bsp_io_port_pin_t io_pin = g_pin_cfg[pin].pin;
  #define PIN_IO_PORT_ADDR(pn) (R_PORT0 + ((uint32_t)(R_PORT1 - R_PORT0) * ((pn) >> 8u)))
  volatile uint16_t *set = &(PIN_IO_PORT_ADDR(io_pin)->POSR);
  volatile uint16_t *clr = &(PIN_IO_PORT_ADDR(io_pin)->PORR);
  uint16_t msk = (1U << (io_pin & 0xFF));
#endif

  uint32_t cyc;

  ARM_DEMCR |= ARM_DEMCR_TRCENA;
  ARM_DWT_CTRL |= ARM_DWT_CTRL_CYCCNTENA;

  cyc = ARM_DWT_CYCCNT + CYCLES_800;
  while (p < end) {
    pix = *p++;
    for (mask = 0x80; mask; mask >>= 1) {
      while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
        ;
      cyc = ARM_DWT_CYCCNT;
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
      dout = 1;
#else
      *set = msk;
#endif
      if (pix & mask) {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T1H)
          ;
      } else {
        while (ARM_DWT_CYCCNT - cyc < CYCLES_800_T0H)
          ;
      }
#if defined(ARDUINO_ARCH_MBED_PORTENTA) || defined(ARDUINO_ARCH_MBED_GIGA)
      dout = 0;
#else
      *clr = msk;
#endif
    }
  }
  while (ARM_DWT_CYCCNT - cyc < CYCLES_800)
    ;

#endif // ARM

#else
#error Architecture not supported
#endif

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

#if defined(ARDUINO_ARCH_CH32)
  PinName const pin_name = digitalPinToPinName(pin);
  gpioPort = get_GPIO_Port(CH_PORT(pin_name));
  gpioPin = CH_GPIO_PIN(pin_name);
  #if defined(CH32V20x_D6)
  if (gpioPort == GPIOC && ((*(volatile uint32_t*)0x40022030) & 0x0F000000) == 0) {
    gpioPin = gpioPin >> 13;
  }
  #endif
#endif
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
