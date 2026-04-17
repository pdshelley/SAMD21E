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

#include "pin-mapping.h"
#include <sam.h>

/*
 * QT Py M0 pin-to-PORT mapping table.
 * Index = Arduino pin number.
 *
 *  D0  / A0  – PA2   ADC ch 0  / DAC
 *  D1  / A1  – PA3   ADC ch 1  / AREF
 *  D2  / A2  – PA4   ADC ch 4  / TCC0 ch0
 *  D3  / A3  – PA5   ADC ch 5  / TCC0 ch1
 *  D4        – PA16  SERCOM1 SDA / TCC2 ch0
 *  D5        – PA17  SERCOM1 SCL / TCC2 ch1
 *  D6  / A6  – PA6   SERCOM0 TX  / TCC1 ch0
 *  D7  / A7  – PA7   SERCOM0 RX  / TCC1 ch1
 *  D8  / A8  – PA11  SERCOM2 SCK / TCC0 ch3
 *  D9  / A9  – PA9   SERCOM2 MISO/ TCC1 ch3
 *  D10 / A10 – PA10  SERCOM2 MOSI/ TCC0 ch2
 *  D11       – PA18  NeoPixel data
 *  D12       – PA15  NeoPixel power enable
 *  D13       – PA27  (fake output)
 *  D14       – PA23  SERCOM3 SCK1
 *  D15       – PA19  SERCOM3 MISO1
 *  D16       – PA22  SERCOM3 MOSI1
 *  D17       – PA8   SERCOM3 CS1
 *  D18       – PA28  USB host enable
 *  D19       – PA24  USB D-
 *  D20       – PA25  USB D+
 */
const PinDescription g_APinDescription[] = {
    /* D0  / A0  */ {PORTA, 2, PIO_ANALOG, PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG,
                     ADC_Channel0, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_2},
    /* D1  / A1  */
    {PORTA, 3, PIO_ANALOG, PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG, ADC_Channel1,
     NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_3},
    /* D2  / A2  */
    {PORTA, 4, PIO_ANALOG,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER,
     ADC_Channel4, PWM0_CH0, TCC0_CH0, EXTERNAL_INT_4},
    /* D3  / A3  */
    {PORTA, 5, PIO_ANALOG,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER,
     ADC_Channel5, PWM0_CH1, TCC0_CH1, EXTERNAL_INT_5},
    /* D4        */
    {PORTA, 16, PIO_SERCOM, PIN_ATTR_DIGITAL | PIN_ATTR_PWM | PIN_ATTR_TIMER,
     No_ADC_Channel, PWM2_CH0, TCC2_CH0, EXTERNAL_INT_0},
    /* D5        */
    {PORTA, 17, PIO_SERCOM, PIN_ATTR_DIGITAL | PIN_ATTR_PWM | PIN_ATTR_TIMER,
     No_ADC_Channel, PWM2_CH1, TCC2_CH1, EXTERNAL_INT_1},
    /* D6  / A6  */
    {PORTA, 6, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER,
     ADC_Channel6, PWM1_CH0, TCC1_CH0, EXTERNAL_INT_6},
    /* D7  / A7  */
    {PORTA, 7, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER,
     ADC_Channel7, PWM1_CH1, TCC1_CH1, EXTERNAL_INT_7},
    /* D8  / A8  */
    {PORTA, 11, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER_ALT,
     ADC_Channel19, PWM0_CH3, TCC0_CH3, EXTERNAL_INT_11},
    /* D9  / A9  */
    {PORTA, 9, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER_ALT,
     ADC_Channel17, PWM1_CH3, TCC1_CH1, EXTERNAL_INT_9},
    /* D10 / A10 */
    {PORTA, 10, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER_ALT,
     ADC_Channel18, PWM0_CH2, TCC0_CH2, EXTERNAL_INT_10},
    /* D11       */
    {PORTA, 18, PIO_DIGITAL, PIN_ATTR_DIGITAL, No_ADC_Channel, NOT_ON_PWM,
     NOT_ON_TIMER, EXTERNAL_INT_2},
    /* D12       */
    {PORTA, 15, PIO_DIGITAL, PIN_ATTR_DIGITAL, No_ADC_Channel, NOT_ON_PWM,
     NOT_ON_TIMER, EXTERNAL_INT_15},
    /* D13       */
    {PORTA, 27, PIO_OUTPUT, PIN_ATTR_DIGITAL, No_ADC_Channel, NOT_ON_PWM,
     NOT_ON_TIMER, EXTERNAL_INT_NONE},
    /* D14       */
    {PORTA, 23, PIO_SERCOM,
     PIN_ATTR_DIGITAL | PIN_ATTR_PWM | PIN_ATTR_TIMER_ALT, No_ADC_Channel,
     PWM0_CH5, TCC0_CH1, EXTERNAL_INT_7},
    /* D15       */
    {PORTA, 19, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_PWM | PIN_ATTR_TIMER, No_ADC_Channel, PWM3_CH1,
     TC3_CH1, EXTERNAL_INT_3},
    /* D16       */
    {PORTA, 22, PIO_SERCOM,
     PIN_ATTR_DIGITAL | PIN_ATTR_PWM | PIN_ATTR_TIMER_ALT, No_ADC_Channel,
     PWM0_CH4, TCC0_CH0, EXTERNAL_INT_6},
    /* D17       */
    {PORTA, 8, PIO_SERCOM_ALT,
     PIN_ATTR_DIGITAL | PIN_ATTR_ANALOG | PIN_ATTR_PWM | PIN_ATTR_TIMER_ALT,
     ADC_Channel16, PWM1_CH2, TCC1_CH0, EXTERNAL_INT_NMI},
    /* D18       */
    {PORTA, 28, PIO_COM, PIN_ATTR_NONE, No_ADC_Channel, NOT_ON_PWM,
     NOT_ON_TIMER, EXTERNAL_INT_NONE},
    /* D19       */
    {PORTA, 24, PIO_COM, PIN_ATTR_NONE, No_ADC_Channel, NOT_ON_PWM,
     NOT_ON_TIMER, EXTERNAL_INT_NONE},
    /* D20       */
    {PORTA, 25, PIO_COM, PIN_ATTR_NONE, No_ADC_Channel, NOT_ON_PWM,
     NOT_ON_TIMER, EXTERNAL_INT_NONE},
};

void initVariant(void) {
    /* Power up the on-board NeoPixel: PA15 output high */
    PORT->Group[PORTA].DIRSET.reg = (1ul << NEO_PWR_BIT);
    PORT->Group[PORTA].OUTSET.reg = (1ul << NEO_PWR_BIT);
}
