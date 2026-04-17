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

#ifndef _VARIANT_QTPY_ZERO_
#define _VARIANT_QTPY_ZERO_

// The definitions here needs a SAMD core >=1.6.10
#define ARDUINO_SAMD_VARIANT_COMPLIANCE 10610

/*----------------------------------------------------------------------------
 *        Definitions
 *----------------------------------------------------------------------------*/

/** Frequency of the board main oscillator */
#define VARIANT_MAINOSC   (32768ul)

/** Master clock frequency */
#define VARIANT_MCK       (F_CPU)

/*----------------------------------------------------------------------------
 *        Headers
 *----------------------------------------------------------------------------*/

#include "WVariant.h"

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

/*----------------------------------------------------------------------------
 *        Pins
 *----------------------------------------------------------------------------*/

// Number of pins defined in PinDescription array
#define PINS_COUNT           (21u)
#define NUM_DIGITAL_PINS     (21u)

#define PIN_NEOPIXEL         (11u)

#ifdef __cplusplus
}
#endif

#endif /* _VARIANT_QTPY_ZERO_ */
