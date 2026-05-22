// SAMD21 (QT Py, crystal-less) clock init: 48 MHz CPU via DFLL48M.

#include <sam.h>

#define OSC32K_HZ 32768ul

void SystemInit(void) {
    NVMCTRL->CTRLB.bit.RWS = NVMCTRL_CTRLB_RWS_HALF_Val;
    PM->APBAMASK.reg |= PM_APBAMASK_GCLK;

    {
        uint32_t calib =
            (*((uint32_t *)FUSES_OSC32K_CAL_ADDR) & FUSES_OSC32K_CAL_Msk) >>
            FUSES_OSC32K_CAL_Pos;
        SYSCTRL->OSC32K.reg = SYSCTRL_OSC32K_CALIB(calib) |
                              SYSCTRL_OSC32K_STARTUP(0x6u) |
                              SYSCTRL_OSC32K_EN32K | SYSCTRL_OSC32K_ENABLE;
        while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_OSC32KRDY) == 0)
            ;
    }

    GCLK->CTRL.reg = GCLK_CTRL_SWRST;
    while ((GCLK->CTRL.reg & GCLK_CTRL_SWRST) &&
           (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY))
        ;

    GCLK->GENDIV.reg = GCLK_GENDIV_ID(1);
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(1) | GCLK_GENCTRL_SRC_OSC32K |
                        GCLK_GENCTRL_GENEN;
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_ID(0) | GCLK_CLKCTRL_GEN_GCLK1 |
                        GCLK_CLKCTRL_CLKEN;
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    SYSCTRL->DFLLCTRL.reg = SYSCTRL_DFLLCTRL_ENABLE;
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    SYSCTRL->DFLLMUL.reg =
        SYSCTRL_DFLLMUL_CSTEP(31) | SYSCTRL_DFLLMUL_FSTEP(511) |
        SYSCTRL_DFLLMUL_MUL((F_CPU + OSC32K_HZ / 2) / OSC32K_HZ);
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    {
        uint32_t coarse =
            (*((uint32_t *)(NVMCTRL_OTP4) + (58 / 32)) >> (58 % 32)) & ((1 << 6) - 1);
        if (coarse == 0x3f) {
            coarse = 0x1f;
        }
        SYSCTRL->DFLLVAL.bit.COARSE = coarse;
        SYSCTRL->DFLLVAL.bit.FINE = 0x1ff;
    }

    SYSCTRL->DFLLMUL.reg = SYSCTRL_DFLLMUL_CSTEP(0x1f / 4) | SYSCTRL_DFLLMUL_FSTEP(10) |
                           SYSCTRL_DFLLMUL_MUL(48000);
    SYSCTRL->DFLLCTRL.reg = 0;
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    SYSCTRL->DFLLCTRL.reg = SYSCTRL_DFLLCTRL_MODE | SYSCTRL_DFLLCTRL_CCDIS |
                            SYSCTRL_DFLLCTRL_USBCRM | SYSCTRL_DFLLCTRL_BPLCKC;
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    SYSCTRL->DFLLCTRL.reg |= SYSCTRL_DFLLCTRL_ENABLE;
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    GCLK->GENDIV.reg = GCLK_GENDIV_ID(0);
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(0) | GCLK_GENCTRL_SRC_DFLL48M |
                        GCLK_GENCTRL_IDC | GCLK_GENCTRL_GENEN;
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    SYSCTRL->OSC8M.bit.PRESC = SYSCTRL_OSC8M_PRESC_0_Val;
    SYSCTRL->OSC8M.bit.ONDEMAND = 0;

    GCLK->GENDIV.reg = GCLK_GENDIV_ID(3);
    GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(3) | GCLK_GENCTRL_SRC_OSC8M | GCLK_GENCTRL_GENEN;
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    PM->CPUSEL.reg = PM_CPUSEL_CPUDIV_DIV1;
    PM->APBASEL.reg = PM_APBASEL_APBADIV_DIV1_Val;
    PM->APBBSEL.reg = PM_APBBSEL_APBBDIV_DIV1_Val;
    PM->APBCSEL.reg = PM_APBCSEL_APBCDIV_DIV1_Val;

    extern uint32_t SystemCoreClock;
    SystemCoreClock = F_CPU;
}
