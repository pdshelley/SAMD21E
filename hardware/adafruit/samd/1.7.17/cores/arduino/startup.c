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

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

/*
 * SystemInit() for SAMD21 + CRYSTALLESS (QT Py M0 / SAMD21E18A).
 * SAMD51 clock configuration and the has-crystal branches have been removed.
 */

#include "sam.h"
#include "variant.h"

#include <stdio.h>

/* Constants for Clock generators */
#define GENERIC_CLOCK_GENERATOR_MAIN      (0u)
#define GENERIC_CLOCK_GENERATOR_XOSC32K   (1u)
#define GENERIC_CLOCK_GENERATOR_OSC32K    (1u)
#define GENERIC_CLOCK_GENERATOR_OSCULP32K (2u) /* Initialized at reset for WDT */
#define GENERIC_CLOCK_GENERATOR_OSC8M     (3u)
/* Constants for Clock multiplexers */
#define GENERIC_CLOCK_MULTIPLEXER_DFLL48M (0u)

void SystemInit( void )
{
  /**
   * At reset:
   *  - OSC8M clock source is enabled with a divider by 8 (1MHz).
   *  - Generic Clock Generator 0 (GCLKMAIN) is using OSC8M as source.
   *
   * CRYSTALLESS path (QT Py M0):
   *  1) Enable OSC32K (internal) as DFLL48M reference
   *  2) Put OSC32K as source of Generic Clock Generator 1
   *  3) Put GCLK1 as source for DFLL48M reference
   *  4) Enable DFLL48M in USB clock recovery mode
   *  5) Switch GCLK0 to DFLL48M (CPU @ 48MHz)
   *  6) Prescale OSC8M to 8MHz
   *  7) Put OSC8M as source for Generic Clock Generator 3
   *  8) Load ADC factory calibration
   *  9) Disable automatic NVM writes
   */

  /* Set 1 Flash Wait State for 48MHz, cf tables 20.9 and 35.27 in SAMD21 Datasheet */
  NVMCTRL->CTRLB.bit.RWS = NVMCTRL_CTRLB_RWS_HALF_Val ;

  /* Turn on the digital interface clock */
  PM->APBAMASK.reg |= PM_APBAMASK_GCLK ;

  /* ----------------------------------------------------------------------------------------------
   * 1) Enable OSC32K clock (Internal 32.768Hz oscillator)
   */
  {
    uint32_t calib = (*((uint32_t *) FUSES_OSC32K_CAL_ADDR) & FUSES_OSC32K_CAL_Msk) >> FUSES_OSC32K_CAL_Pos;

    SYSCTRL->OSC32K.reg = SYSCTRL_OSC32K_CALIB(calib) |
                          SYSCTRL_OSC32K_STARTUP( 0x6u ) | // cf table 15.10 of product datasheet in chapter 15.8.6
                          SYSCTRL_OSC32K_EN32K |
                          SYSCTRL_OSC32K_ENABLE;

    while ( (SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_OSC32KRDY) == 0 ); // Wait for oscillator stabilization
  }

  /* Software reset the GCLK module to ensure it is re-initialized correctly */
  GCLK->CTRL.reg = GCLK_CTRL_SWRST ;

  while ( (GCLK->CTRL.reg & GCLK_CTRL_SWRST) && (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY) )
  {
    /* Wait for reset to complete */
  }

  /* ----------------------------------------------------------------------------------------------
   * 2) Put OSC32K as source of Generic Clock Generator 1
   */
  GCLK->GENDIV.reg = GCLK_GENDIV_ID( GENERIC_CLOCK_GENERATOR_XOSC32K ) ; // Generic Clock Generator 1

  while ( GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY )
  {
    /* Wait for synchronization */
  }

  /* Write Generic Clock Generator 1 configuration */
  GCLK->GENCTRL.reg = GCLK_GENCTRL_ID( GENERIC_CLOCK_GENERATOR_OSC32K ) | // Generic Clock Generator 1
                      GCLK_GENCTRL_SRC_OSC32K | // Selected source is Internal 32KHz Oscillator
                      GCLK_GENCTRL_GENEN ;

  while ( GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY )
  {
    /* Wait for synchronization */
  }

  /* ----------------------------------------------------------------------------------------------
   * 3) Put Generic Clock Generator 1 as source for Generic Clock Multiplexer 0 (DFLL48M reference)
   */
  GCLK->CLKCTRL.reg = GCLK_CLKCTRL_ID( GENERIC_CLOCK_MULTIPLEXER_DFLL48M ) | // Generic Clock Multiplexer 0
                      GCLK_CLKCTRL_GEN_GCLK1 | // Generic Clock Generator 1 is source
                      GCLK_CLKCTRL_CLKEN ;

  while ( GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY )
  {
    /* Wait for synchronization */
  }

  /* ----------------------------------------------------------------------------------------------
   * 4) Enable DFLL48M clock
   */

  /* Remove the OnDemand mode, Bug http://avr32.icgroup.norway.atmel.com/bugzilla/show_bug.cgi?id=9905 */
  SYSCTRL->DFLLCTRL.reg = SYSCTRL_DFLLCTRL_ENABLE;

  while ( (SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0 )
  {
    /* Wait for synchronization */
  }

  SYSCTRL->DFLLMUL.reg = SYSCTRL_DFLLMUL_CSTEP( 31 ) | // Coarse step is 31, half of the max value
                         SYSCTRL_DFLLMUL_FSTEP( 511 ) | // Fine step is 511, half of the max value
                         SYSCTRL_DFLLMUL_MUL( (VARIANT_MCK + VARIANT_MAINOSC/2) / VARIANT_MAINOSC ) ; // External 32KHz is the reference

  while ( (SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0 )
  {
    /* Wait for synchronization */
  }

  #define NVM_SW_CALIB_DFLL48M_COARSE_VAL 58

  /* Turn on DFLL */
  {
    uint32_t coarse = ( *((uint32_t *)(NVMCTRL_OTP4) + (NVM_SW_CALIB_DFLL48M_COARSE_VAL / 32)) >> (NVM_SW_CALIB_DFLL48M_COARSE_VAL % 32) )
                     & ((1 << 6) - 1);
    if (coarse == 0x3f) {
      coarse = 0x1f;
    }
    // TODO(tannewt): Load this value from memory we've written previously. There
    // isn't a value from the Atmel factory.
    uint32_t fine = 0x1ff;

    SYSCTRL->DFLLVAL.bit.COARSE = coarse;
    SYSCTRL->DFLLVAL.bit.FINE = fine;
  }

  /* Write full configuration to DFLL control register */
  SYSCTRL->DFLLMUL.reg = SYSCTRL_DFLLMUL_CSTEP( 0x1f / 4 ) | // Coarse step is 31, half of the max value
                         SYSCTRL_DFLLMUL_FSTEP( 10 ) |
                         SYSCTRL_DFLLMUL_MUL( (48000) ) ;

  SYSCTRL->DFLLCTRL.reg = 0;

  while ( (SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0 )
  {
    /* Wait for synchronization */
  }

  SYSCTRL->DFLLCTRL.reg =  SYSCTRL_DFLLCTRL_MODE |
                           SYSCTRL_DFLLCTRL_CCDIS |
                           SYSCTRL_DFLLCTRL_USBCRM | /* USB correction */
                           SYSCTRL_DFLLCTRL_BPLCKC;

  while ( (SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0 )
  {
    /* Wait for synchronization */
  }

  /* Enable the DFLL */
  SYSCTRL->DFLLCTRL.reg |= SYSCTRL_DFLLCTRL_ENABLE ;

  while ( (SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0 )
  {
    /* Wait for synchronization */
  }

  /* ----------------------------------------------------------------------------------------------
   * 5) Switch Generic Clock Generator 0 to DFLL48M. CPU will run at 48MHz.
   */
  GCLK->GENDIV.reg = GCLK_GENDIV_ID( GENERIC_CLOCK_GENERATOR_MAIN ) ; // Generic Clock Generator 0

  while ( GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY )
  {
    /* Wait for synchronization */
  }

  /* Write Generic Clock Generator 0 configuration */
  GCLK->GENCTRL.reg = GCLK_GENCTRL_ID( GENERIC_CLOCK_GENERATOR_MAIN ) | // Generic Clock Generator 0
                      GCLK_GENCTRL_SRC_DFLL48M | // Selected source is DFLL 48MHz
                      GCLK_GENCTRL_IDC | // Set 50/50 duty cycle
                      GCLK_GENCTRL_GENEN ;

  while ( GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY )
  {
    /* Wait for synchronization */
  }

  /* ----------------------------------------------------------------------------------------------
   * 6) Modify PRESCaler value of OSC8M to have 8MHz
   */
  SYSCTRL->OSC8M.bit.PRESC = SYSCTRL_OSC8M_PRESC_0_Val ;  //CMSIS 4.5 changed the prescaler defines
  SYSCTRL->OSC8M.bit.ONDEMAND = 0 ;

  /* ----------------------------------------------------------------------------------------------
   * 7) Put OSC8M as source for Generic Clock Generator 3
   */
  GCLK->GENDIV.reg = GCLK_GENDIV_ID( GENERIC_CLOCK_GENERATOR_OSC8M ) ; // Generic Clock Generator 3

  /* Write Generic Clock Generator 3 configuration */
  GCLK->GENCTRL.reg = GCLK_GENCTRL_ID( GENERIC_CLOCK_GENERATOR_OSC8M ) | // Generic Clock Generator 3
                      GCLK_GENCTRL_SRC_OSC8M | // Selected source is RC OSC 8MHz (already enabled at reset)
                      GCLK_GENCTRL_GENEN ;

  while ( GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY )
  {
    /* Wait for synchronization */
  }

  /*
   * Now that all system clocks are configured, we can set CPU and APBx BUS clocks.
   * There values are normally the one present after Reset.
   */
  PM->CPUSEL.reg  = PM_CPUSEL_CPUDIV_DIV1 ;
  PM->APBASEL.reg = PM_APBASEL_APBADIV_DIV1_Val ;
  PM->APBBSEL.reg = PM_APBBSEL_APBBDIV_DIV1_Val ;
  PM->APBCSEL.reg = PM_APBCSEL_APBCDIV_DIV1_Val ;

  SystemCoreClock = VARIANT_MCK ;

  /* ----------------------------------------------------------------------------------------------
   * 8) Load ADC factory calibration values
   */

  /* ADC Bias Calibration */
  {
    uint32_t bias = (*((uint32_t *) ADC_FUSES_BIASCAL_ADDR) & ADC_FUSES_BIASCAL_Msk) >> ADC_FUSES_BIASCAL_Pos;

    /* ADC Linearity bits 4:0 */
    uint32_t linearity = (*((uint32_t *) ADC_FUSES_LINEARITY_0_ADDR) & ADC_FUSES_LINEARITY_0_Msk) >> ADC_FUSES_LINEARITY_0_Pos;

    /* ADC Linearity bits 7:5 */
    linearity |= ((*((uint32_t *) ADC_FUSES_LINEARITY_1_ADDR) & ADC_FUSES_LINEARITY_1_Msk) >> ADC_FUSES_LINEARITY_1_Pos) << 5;

    ADC->CALIB.reg = ADC_CALIB_BIAS_CAL(bias) | ADC_CALIB_LINEARITY_CAL(linearity);
  }

  /*
   * 9) Disable automatic NVM write operations
   */
  NVMCTRL->CTRLB.bit.MANW = 1;
}
