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

#include <sam.h>
#include "variant.h"

/*
 * System Core Clock is at 1MHz (8MHz/8) at Reset.
 * It is switched to 48MHz in the Reset Handler (startup.c).
 */
uint32_t SystemCoreClock = 1000000ul;

/*
 * Start the 1ms SysTick used by millis() / micros() / delay().
 */
void init(void)
{
  if ( SysTick_Config( SystemCoreClock / 1000 ) )
  {
    while ( 1 ) ;
  }
  NVIC_SetPriority( SysTick_IRQn, (1 << __NVIC_PRIO_BITS) - 2 );
}
