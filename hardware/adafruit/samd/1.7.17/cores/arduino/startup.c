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

/* Constants for Clock generators */
#define GENERIC_CLOCK_GENERATOR_MAIN      (0u)
#define GENERIC_CLOCK_GENERATOR_XOSC32K   (1u)
#define GENERIC_CLOCK_GENERATOR_OSC32K    (1u)
#define GENERIC_CLOCK_GENERATOR_OSCULP32K (2u)
#define GENERIC_CLOCK_GENERATOR_OSC8M     (3u)

/* Constants for Clock multiplexers */
#define GENERIC_CLOCK_MULTIPLEXER_DFLL48M (0u)

void SystemInit(void)
{
  /**
   * CRYSTALLESS path (QT Py M0):
   *  1) Enable OSC32K (internal) as DFLL48M reference
   *  2) Put OSC32K as source of Generic Clock Generator 1
   *  3) Put GCLK1 as source for DFLL48M reference
   *  4) Enable DFLL48M in USB clock recovery mode
   *  5) Switch GCLK0 to DFLL48M (CPU @ 48 MHz)
   *  6) Prescale OSC8M to 8 MHz
   *  7) Put OSC8M as source for Generic Clock Generator 3
   *  8) Load ADC factory calibration
   *  9) Disable automatic NVM writes
   */

  /* Set 1 Flash Wait State for 48 MHz (tables 20.9 and 35.27 in SAMD21 Datasheet) */
  NVMCTRL->CTRLB.bit.RWS = NVMCTRL_CTRLB_RWS_HALF_Val;

  /* Turn on the digital interface clock */
  PM->APBAMASK.reg |= PM_APBAMASK_GCLK;

  /* 1) Enable OSC32K clock */
  {
    uint32_t calib = (*((uint32_t *) FUSES_OSC32K_CAL_ADDR) & FUSES_OSC32K_CAL_Msk) >> FUSES_OSC32K_CAL_Pos;

    SYSCTRL->OSC32K.reg = SYSCTRL_OSC32K_CALIB(calib) |
                          SYSCTRL_OSC32K_STARTUP(0x6u) |
                          SYSCTRL_OSC32K_EN32K |
                          SYSCTRL_OSC32K_ENABLE;

    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_OSC32KRDY) == 0)
      ;
  }

  /* Software reset the GCLK module */
  GCLK->CTRL.reg = GCLK_CTRL_SWRST;

  while ((GCLK->CTRL.reg & GCLK_CTRL_SWRST) && (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY))
    ;

  /* 2) Put OSC32K as source of Generic Clock Generator 1 */
  GCLK->GENDIV.reg = GCLK_GENDIV_ID(GENERIC_CLOCK_GENERATOR_XOSC32K);

  while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
    ;

  GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(GENERIC_CLOCK_GENERATOR_OSC32K) |
                      GCLK_GENCTRL_SRC_OSC32K |
                      GCLK_GENCTRL_GENEN;

  while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
    ;

  /* 3) GCLK1 → DFLL48M reference */
  GCLK->CLKCTRL.reg = GCLK_CLKCTRL_ID(GENERIC_CLOCK_MULTIPLEXER_DFLL48M) |
                      GCLK_CLKCTRL_GEN_GCLK1 |
                      GCLK_CLKCTRL_CLKEN;

  while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
    ;

  /* 4) Enable DFLL48M */
  SYSCTRL->DFLLCTRL.reg = SYSCTRL_DFLLCTRL_ENABLE;

  while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
    ;

  SYSCTRL->DFLLMUL.reg = SYSCTRL_DFLLMUL_CSTEP(31) |
                         SYSCTRL_DFLLMUL_FSTEP(511) |
                         SYSCTRL_DFLLMUL_MUL((VARIANT_MCK + VARIANT_MAINOSC / 2) / VARIANT_MAINOSC);

  while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
    ;

  #define NVM_SW_CALIB_DFLL48M_COARSE_VAL 58

  {
    uint32_t coarse = (*((uint32_t *)(NVMCTRL_OTP4) + (NVM_SW_CALIB_DFLL48M_COARSE_VAL / 32)) >> (NVM_SW_CALIB_DFLL48M_COARSE_VAL % 32))
                     & ((1 << 6) - 1);
    if (coarse == 0x3f)
      coarse = 0x1f;

    SYSCTRL->DFLLVAL.bit.COARSE = coarse;
    SYSCTRL->DFLLVAL.bit.FINE   = 0x1ff;
  }

  SYSCTRL->DFLLMUL.reg = SYSCTRL_DFLLMUL_CSTEP(0x1f / 4) |
                         SYSCTRL_DFLLMUL_FSTEP(10) |
                         SYSCTRL_DFLLMUL_MUL(48000);

  SYSCTRL->DFLLCTRL.reg = 0;

  while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
    ;

  SYSCTRL->DFLLCTRL.reg = SYSCTRL_DFLLCTRL_MODE  |
                          SYSCTRL_DFLLCTRL_CCDIS  |
                          SYSCTRL_DFLLCTRL_USBCRM |
                          SYSCTRL_DFLLCTRL_BPLCKC;

  while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
    ;

  SYSCTRL->DFLLCTRL.reg |= SYSCTRL_DFLLCTRL_ENABLE;

  while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
    ;

  /* 5) Switch GCLK0 to DFLL48M → CPU @ 48 MHz */
  GCLK->GENDIV.reg = GCLK_GENDIV_ID(GENERIC_CLOCK_GENERATOR_MAIN);

  while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
    ;

  GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(GENERIC_CLOCK_GENERATOR_MAIN) |
                      GCLK_GENCTRL_SRC_DFLL48M |
                      GCLK_GENCTRL_IDC |
                      GCLK_GENCTRL_GENEN;

  while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
    ;

  /* 6) Prescale OSC8M to 8 MHz */
  SYSCTRL->OSC8M.bit.PRESC    = SYSCTRL_OSC8M_PRESC_0_Val;
  SYSCTRL->OSC8M.bit.ONDEMAND = 0;

  /* 7) OSC8M → GCLK3 */
  GCLK->GENDIV.reg = GCLK_GENDIV_ID(GENERIC_CLOCK_GENERATOR_OSC8M);

  GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(GENERIC_CLOCK_GENERATOR_OSC8M) |
                      GCLK_GENCTRL_SRC_OSC8M |
                      GCLK_GENCTRL_GENEN;

  while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
    ;

  PM->CPUSEL.reg  = PM_CPUSEL_CPUDIV_DIV1;
  PM->APBASEL.reg = PM_APBASEL_APBADIV_DIV1_Val;
  PM->APBBSEL.reg = PM_APBBSEL_APBBDIV_DIV1_Val;
  PM->APBCSEL.reg = PM_APBCSEL_APBCDIV_DIV1_Val;

  SystemCoreClock = VARIANT_MCK;

  /* 8) Load ADC factory calibration values */
  {
    uint32_t bias = (*((uint32_t *) ADC_FUSES_BIASCAL_ADDR) & ADC_FUSES_BIASCAL_Msk) >> ADC_FUSES_BIASCAL_Pos;
    uint32_t linearity = (*((uint32_t *) ADC_FUSES_LINEARITY_0_ADDR) & ADC_FUSES_LINEARITY_0_Msk) >> ADC_FUSES_LINEARITY_0_Pos;
    linearity |= ((*((uint32_t *) ADC_FUSES_LINEARITY_1_ADDR) & ADC_FUSES_LINEARITY_1_Msk) >> ADC_FUSES_LINEARITY_1_Pos) << 5;

    ADC->CALIB.reg = ADC_CALIB_BIAS_CAL(bias) | ADC_CALIB_LINEARITY_CAL(linearity);
  }

  /* 9) Disable automatic NVM write operations */
  NVMCTRL->CTRLB.bit.MANW = 1;
}
