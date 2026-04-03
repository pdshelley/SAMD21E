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

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "variant.h"
#include "Arduino.h"
/*
 * Pins descriptions
 */
const PinDescription g_APinDescription[]=
{
  // TRRS Tip, D0 / DAC / A0
  { PORTA, 2, PIO_ANALOG, PIN_ATTR_ANALOG, ADC_Channel0, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_2 },
  // TRRS Tip Switch, D1, A1
  { PORTA, 3, PIO_ANALOG, PIN_ATTR_ANALOG, ADC_Channel1, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_3 },

  // TRRS Ring 1, D2, A2
  { PORTA, 6, PIO_ANALOG, (PIN_ATTR_DIGITAL|PIN_ATTR_PWM|PIN_ATTR_TIMER|PIN_ATTR_ANALOG), ADC_Channel6, PWM1_CH0, TCC1_CH0, EXTERNAL_INT_6 },
  // TRRS Ring 1 Switch, D3, A3
  { PORTA, 7, PIO_ANALOG, (PIN_ATTR_DIGITAL|PIN_ATTR_PWM|PIN_ATTR_TIMER|PIN_ATTR_ANALOG), ADC_Channel7, PWM1_CH1, TCC1_CH1, EXTERNAL_INT_7 },

  // TRRS Ring2, D4, A4
  { PORTA, 4, PIO_ANALOG, PIN_ATTR_DIGITAL, ADC_Channel4, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_4 },

  // TRRS Sleeve, D5, A5
  { PORTA, 5, PIO_ANALOG, PIN_ATTR_DIGITAL, ADC_Channel5, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_5 },

  // Internal NeoPixel / D6
  { PORTA, 1, PIO_ANALOG, PIN_ATTR_ANALOG, No_ADC_Channel, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_NONE },

  // QT SDA D7
  { PORTA,  8, PIO_SERCOM_ALT, (PIN_ATTR_DIGITAL|PIN_ATTR_PWM|PIN_ATTR_TIMER), ADC_Channel16, PWM0_CH0, TCC0_CH0, EXTERNAL_INT_NMI },  // TCC0/WO[0]

  // QT SCL D8
  { PORTA,  9, PIO_SERCOM_ALT, (PIN_ATTR_DIGITAL|PIN_ATTR_PWM|PIN_ATTR_TIMER), ADC_Channel17, PWM0_CH1, TCC0_CH1, EXTERNAL_INT_9 }, // TCC0/WO[1]

  // USB pins D9, D10, D11
  { PORTA, 28, PIO_COM, PIN_ATTR_NONE, No_ADC_Channel, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_NONE }, // USB Host enable
  { PORTA, 24, PIO_COM, PIN_ATTR_NONE, No_ADC_Channel, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_NONE }, // USB/DM
  { PORTA, 25, PIO_COM, PIN_ATTR_NONE, No_ADC_Channel, NOT_ON_PWM, NOT_ON_TIMER, EXTERNAL_INT_NONE }, // USB/DP

} ;

const void* g_apTCInstances[TCC_INST_NUM+TC_INST_NUM]={ TCC0, TCC1, TCC2, TC3, TC4, TC5 } ;

// Multi-serial objects instantiation
SERCOM sercom0( SERCOM0 ) ;
SERCOM sercom1( SERCOM1 ) ;
SERCOM sercom2( SERCOM2 ) ;
SERCOM sercom3( SERCOM3 ) ;
