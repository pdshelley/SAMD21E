/*
  Copyright (c) 2015 Arduino LLC.  All right reserved.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.
*/

#include "Arduino.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * System Core Clock is at 1MHz (8MHz/8) at Reset.
 * It is switched to 48MHz in the Reset Handler (startup.c).
 */
uint32_t SystemCoreClock = 1000000ul;

/*
 * SAMD21 board initialization (minimal).
 *
 * At reset:
 *   - ResetHandler + SystemInit() have configured the system clock (48MHz).
 *   - All PORT lines are configured as inputs with input/output/pull disabled.
 * All this function still needs to do is start the 1 ms SysTick used by
 * millis() / micros() / delay().
 */
void init( void )
{
  /* Set SysTick to 1ms interval, common to all Cortex-M variants */
  if ( SysTick_Config( SystemCoreClock / 1000 ) )
  {
    /* Capture error */
    while ( 1 ) ;
  }
  NVIC_SetPriority( SysTick_IRQn, (1 << __NVIC_PRIO_BITS) - 2 );
}

#ifdef __cplusplus
}
#endif
