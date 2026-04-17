/*
  Copyright (c) 2014-2015 Arduino LLC.  All right reserved.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.
*/

#pragma once

#include <limits.h>
#include <sam.h>
#include <stdint.h>

/*----------------------------------------------------------------------------
 *        Board frequency constants
 *----------------------------------------------------------------------------*/

#define VARIANT_MAINOSC (32768ul) /* Internal OSC32K reference */
#define VARIANT_MCK (F_CPU)       /* Master clock (48 MHz) */

/*----------------------------------------------------------------------------
 *        Board pin constants
 *----------------------------------------------------------------------------*/

#define PINS_COUNT (21u)
#define NUM_DIGITAL_PINS (21u)

/* On-board NeoPixel (WS2812B) */
#define PIN_NEOPIXEL (11u) /* Arduino pin 11 = PA18 */

/* Direct PORT bit positions for board peripherals */
#define NEO_DATA_BIT (18u) /* PA18 – NeoPixel data */
#define NEO_PWR_BIT (15u)  /* PA15 – NeoPixel power enable */

/*----------------------------------------------------------------------------
 *        Pin-description types  (formerly in WVariant.h)
 *----------------------------------------------------------------------------*/

typedef enum _EAnalogChannel {
    No_ADC_Channel = -1,
    ADC_Channel0 = 0,
    ADC_Channel1 = 1,
    ADC_Channel2 = 2,
    ADC_Channel3 = 3,
    ADC_Channel4 = 4,
    ADC_Channel5 = 5,
    ADC_Channel6 = 6,
    ADC_Channel7 = 7,
    ADC_Channel10 = 10,
    ADC_Channel11 = 11,
    ADC_Channel16 = 16,
    ADC_Channel17 = 17,
    ADC_Channel18 = 18,
    ADC_Channel19 = 19,
    DAC_Channel0,
    DAC_Channel1,
    ADC_Channel_Bandgap = 0x1B,
    ADC_Channel_PTAT = 0x1C,
} EAnalogChannel;

typedef enum _ETCChannel {
    NOT_ON_TIMER = -1,
    TCC0_CH0 = (0 << 8) | 0,
    TCC0_CH1 = (0 << 8) | 1,
    TCC0_CH2 = (0 << 8) | 2,
    TCC0_CH3 = (0 << 8) | 3,
    TCC1_CH0 = (1 << 8) | 0,
    TCC1_CH1 = (1 << 8) | 1,
    TCC2_CH0 = (2 << 8) | 0,
    TCC2_CH1 = (2 << 8) | 1,
    /* TCC0 channels 4-7 alias back to 0-3 (TCC0 has 4 outputs) */
    TCC0_CH4 = (0 << 8) | 0,
    TCC0_CH5 = (0 << 8) | 1,
    TCC0_CH6 = (0 << 8) | 2,
    TCC0_CH7 = (0 << 8) | 3,
    /* TCC1 channels 2-3 alias back to 0-1 */
    TCC1_CH2 = (1 << 8) | 0,
    TCC1_CH3 = (1 << 8) | 1,
    /* TCC2 channels 2-3 alias back to 0-1 */
    TCC2_CH2 = (2 << 8) | 0,
    TCC2_CH3 = (2 << 8) | 1,
    TC3_CH0 = (3 << 8) | 0,
    TC3_CH1 = (3 << 8) | 1,
    TC4_CH0 = (4 << 8) | 0,
    TC4_CH1 = (4 << 8) | 1,
    TC5_CH0 = (5 << 8) | 0,
    TC5_CH1 = (5 << 8) | 1,
} ETCChannel;

typedef enum _EPWMChannel {
    NOT_ON_PWM = -1,
    PWM0_CH0 = TCC0_CH0,
    PWM0_CH1 = TCC0_CH1,
    PWM0_CH2 = TCC0_CH2,
    PWM0_CH3 = TCC0_CH3,
    PWM0_CH4 = TCC0_CH4,
    PWM0_CH5 = TCC0_CH5,
    PWM0_CH6 = TCC0_CH6,
    PWM0_CH7 = TCC0_CH7,
    PWM1_CH0 = TCC1_CH0,
    PWM1_CH1 = TCC1_CH1,
    PWM1_CH2 = TCC1_CH2,
    PWM1_CH3 = TCC1_CH3,
    PWM2_CH0 = TCC2_CH0,
    PWM2_CH1 = TCC2_CH1,
    PWM2_CH2 = TCC2_CH2,
    PWM2_CH3 = TCC2_CH3,
    PWM3_CH0 = TC3_CH0,
    PWM3_CH1 = TC3_CH1,
    PWM4_CH0 = TC4_CH0,
    PWM4_CH1 = TC4_CH1,
    PWM5_CH0 = TC5_CH0,
    PWM5_CH1 = TC5_CH1,
} EPWMChannel;

typedef enum _EPortType {
    NOT_A_PORT = -1,
    PORTA = 0,
    PORTB = 1,
    PORTC = 2,
    PORTD = 3,
} EPortType;

typedef enum {
    EXTERNAL_INT_0 = 0,
    EXTERNAL_INT_1,
    EXTERNAL_INT_2,
    EXTERNAL_INT_3,
    EXTERNAL_INT_4,
    EXTERNAL_INT_5,
    EXTERNAL_INT_6,
    EXTERNAL_INT_7,
    EXTERNAL_INT_8,
    EXTERNAL_INT_9,
    EXTERNAL_INT_10,
    EXTERNAL_INT_11,
    EXTERNAL_INT_12,
    EXTERNAL_INT_13,
    EXTERNAL_INT_14,
    EXTERNAL_INT_15,
    EXTERNAL_INT_NMI,
    EXTERNAL_NUM_INTERRUPTS,
    NOT_AN_INTERRUPT = -1,
    EXTERNAL_INT_NONE = NOT_AN_INTERRUPT,
} EExt_Interrupts;

typedef enum _EPioType {
    PIO_NOT_A_PIN = -1,
    PIO_EXTINT = 0,
    PIO_ANALOG,
    PIO_SERCOM,
    PIO_SERCOM_ALT,
    PIO_TIMER,
    PIO_TIMER_ALT,
    PIO_COM,
    PIO_AC_CLK,
    PIO_DIGITAL,
    PIO_INPUT,
    PIO_INPUT_PULLUP,
    PIO_OUTPUT,
    PIO_PWM = PIO_TIMER,
    PIO_PWM_ALT = PIO_TIMER_ALT,
} EPioType;

#define PIN_ATTR_NONE (0UL << 0)
#define PIN_ATTR_COMBO (1UL << 0)
#define PIN_ATTR_ANALOG (1UL << 1)
#define PIN_ATTR_DIGITAL (1UL << 2)
#define PIN_ATTR_PWM (1UL << 3)
#define PIN_ATTR_TIMER (1UL << 4)
#define PIN_ATTR_TIMER_ALT (1UL << 5)
#define PIN_ATTR_EXTINT (1UL << 6)

typedef struct _PinDescription {
    EPortType ulPort;
    uint32_t ulPin;
    EPioType ulPinType;
    uint32_t ulPinAttribute;
    EAnalogChannel ulADCChannelNumber;
    EPWMChannel ulPWMChannel;
    ETCChannel ulTCChannel;
    EExt_Interrupts ulExtInt;
} PinDescription;

extern const PinDescription g_APinDescription[];

/*----------------------------------------------------------------------------
 *        Generic Clock Multiplexer IDs
 *----------------------------------------------------------------------------*/

#define GCM_DFLL48M_REF (0x00U)
#define GCM_FDPLL96M_INPUT (0x01U)
#define GCM_FDPLL96M_32K (0x02U)
#define GCM_WDT (0x03U)
#define GCM_RTC (0x04U)
#define GCM_EIC (0x05U)
#define GCM_USB (0x06U)
#define GCM_EVSYS_CHANNEL_0 (0x07U)
#define GCM_EVSYS_CHANNEL_1 (0x08U)
#define GCM_EVSYS_CHANNEL_2 (0x09U)
#define GCM_EVSYS_CHANNEL_3 (0x0AU)
#define GCM_EVSYS_CHANNEL_4 (0x0BU)
#define GCM_EVSYS_CHANNEL_5 (0x0CU)
#define GCM_EVSYS_CHANNEL_6 (0x0DU)
#define GCM_EVSYS_CHANNEL_7 (0x0EU)
#define GCM_EVSYS_CHANNEL_8 (0x0FU)
#define GCM_EVSYS_CHANNEL_9 (0x10U)
#define GCM_EVSYS_CHANNEL_10 (0x11U)
#define GCM_EVSYS_CHANNEL_11 (0x12U)
#define GCM_SERCOMx_SLOW (0x13U)
#define GCM_SERCOM0_CORE (0x14U)
#define GCM_SERCOM1_CORE (0x15U)
#define GCM_SERCOM2_CORE (0x16U)
#define GCM_SERCOM3_CORE (0x17U)
#define GCM_SERCOM4_CORE (0x18U)
#define GCM_SERCOM5_CORE (0x19U)
#define GCM_TCC0_TCC1 (0x1AU)
#define GCM_TCC2_TC3 (0x1BU)
#define GCM_TC4_TC5 (0x1CU)
#define GCM_TC6_TC7 (0x1DU)
#define GCM_ADC (0x1EU)
#define GCM_AC_DIG (0x1FU)
#define GCM_AC_ANA (0x20U)
#define GCM_DAC (0x21U)
#define GCM_PTC (0x22U)
#define GCM_I2S_0 (0x23U)
#define GCM_I2S_1 (0x24U)
