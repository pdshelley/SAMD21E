/*
  Original work:
    Copyright (c) 2015 Arduino LLC. All rights reserved.
    SAMD51 support added by Adafruit - Copyright (c) 2018 Dean Miller for Adafruit Industries

  This file is a heavily modified version, simplified for SAMD21 (Cortex-M0+) only and adapted for the Embedded Swift example.

  Modifications:
    Copyright (c) 2026 Swift4Arduino. All rights reserved.

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

extern void systick_init(void);

/* Defined in Application.c */
extern void app_init(void);
extern void app_main(void);

int main(void) {
    systick_init(); /* Start SysTick @ 1 ms (delay.c) */
    app_init();

    for (;;) {
        app_main();
    }

    return 0;
}
