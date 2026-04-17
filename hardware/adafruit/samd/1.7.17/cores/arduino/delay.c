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
#include "delay.h"

/** Tick counter (ms) incremented by SysTick_Handler each millisecond */
static volatile uint32_t _ulTickCount = 0;

unsigned long millis(void)
{
  return _ulTickCount;
}

unsigned long micros(void)
{
  uint32_t ticks, ticks2;
  uint32_t pend, pend2;
  uint32_t count, count2;

  ticks2 = SysTick->VAL;
  pend2  = !!(SCB->ICSR & SCB_ICSR_PENDSTSET_Msk);
  count2 = _ulTickCount;

  do
  {
    ticks  = ticks2;
    pend   = pend2;
    count  = count2;
    ticks2 = SysTick->VAL;
    pend2  = !!(SCB->ICSR & SCB_ICSR_PENDSTSET_Msk);
    count2 = _ulTickCount;
  } while ((pend != pend2) || (count != count2) || (ticks < ticks2));

  return ((count + pend) * 1000) +
         (((SysTick->LOAD - ticks) * (1048576 / (VARIANT_MCK / 1000000))) >> 20);
}

void delay(unsigned long ms)
{
  if (ms == 0)
    return;

  uint32_t start = micros();

  while (ms > 0)
  {
    while (ms > 0 && (micros() - start) >= 1000)
    {
      ms--;
      start += 1000;
    }
  }
}

void SysTick_DefaultHandler(void)
{
  _ulTickCount++;
}
