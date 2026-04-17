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

extern void init(void);
extern void initVariant(void);

/* Defined in Application.c */
extern void app_init(void);
extern void app_main(void);

int main(void)
{
  init();         /* Start SysTick @ 1 ms (wiring.c) */
  initVariant();  /* Board-specific init — NeoPixel power (pin-mapping.c) */
  app_init();

  for (;;)
  {
    app_main();
  }

  return 0;
}
