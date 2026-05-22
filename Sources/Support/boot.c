#include <sam.h>
#include <stdint.h>

uint32_t SystemCoreClock = 1000000ul;

extern void app_init(void);
extern void app_main(void);

static void Dummy_Handler(void) { for (;;); }

#define DEF_IRQ(name) void name(void) __attribute__((weak, alias("Dummy_Handler")))

void Reset_Handler(void);
DEF_IRQ(NMI_Handler);
DEF_IRQ(HardFault_Handler);
DEF_IRQ(SVC_Handler);
DEF_IRQ(PendSV_Handler);
DEF_IRQ(SysTick_Handler);
DEF_IRQ(PM_Handler);
DEF_IRQ(SYSCTRL_Handler);
DEF_IRQ(WDT_Handler);
DEF_IRQ(RTC_Handler);
DEF_IRQ(EIC_Handler);
DEF_IRQ(NVMCTRL_Handler);
DEF_IRQ(DMAC_Handler);
DEF_IRQ(USB_Handler);
DEF_IRQ(EVSYS_Handler);
DEF_IRQ(SERCOM0_Handler);
DEF_IRQ(SERCOM1_Handler);
DEF_IRQ(SERCOM2_Handler);
DEF_IRQ(SERCOM3_Handler);
DEF_IRQ(SERCOM4_Handler);
DEF_IRQ(SERCOM5_Handler);
DEF_IRQ(TCC0_Handler);
DEF_IRQ(TCC1_Handler);
DEF_IRQ(TCC2_Handler);
DEF_IRQ(TC3_Handler);
DEF_IRQ(TC4_Handler);
DEF_IRQ(TC5_Handler);
DEF_IRQ(TC6_Handler);
DEF_IRQ(TC7_Handler);
DEF_IRQ(ADC_Handler);
DEF_IRQ(AC_Handler);
DEF_IRQ(DAC_Handler);
DEF_IRQ(PTC_Handler);
DEF_IRQ(I2S_Handler);

static void clock_init(void) {
#define OSC32K_HZ 32768ul
    NVMCTRL->CTRLB.bit.RWS = NVMCTRL_CTRLB_RWS_HALF_Val;
    PM->APBAMASK.reg |= PM_APBAMASK_GCLK;

    uint32_t calib = (*((uint32_t *)FUSES_OSC32K_CAL_ADDR) & FUSES_OSC32K_CAL_Msk) >>
                     FUSES_OSC32K_CAL_Pos;
    SYSCTRL->OSC32K.reg = SYSCTRL_OSC32K_CALIB(calib) | SYSCTRL_OSC32K_STARTUP(0x6u) |
                          SYSCTRL_OSC32K_EN32K | SYSCTRL_OSC32K_ENABLE;
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_OSC32KRDY) == 0)
        ;

    GCLK->CTRL.reg = GCLK_CTRL_SWRST;
    while ((GCLK->CTRL.reg & GCLK_CTRL_SWRST) && (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY))
        ;

    GCLK->GENDIV.reg = GCLK_GENDIV_ID(1);
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;
    GCLK->GENCTRL.reg = GCLK_GENCTRL_ID(1) | GCLK_GENCTRL_SRC_OSC32K | GCLK_GENCTRL_GENEN;
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_ID(0) | GCLK_CLKCTRL_GEN_GCLK1 | GCLK_CLKCTRL_CLKEN;
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;

    SYSCTRL->DFLLCTRL.reg = SYSCTRL_DFLLCTRL_ENABLE;
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    SYSCTRL->DFLLMUL.reg = SYSCTRL_DFLLMUL_CSTEP(31) | SYSCTRL_DFLLMUL_FSTEP(511) |
                           SYSCTRL_DFLLMUL_MUL((F_CPU + OSC32K_HZ / 2) / OSC32K_HZ);
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;

    uint32_t coarse = (*((uint32_t *)(NVMCTRL_OTP4) + (58 / 32)) >> (58 % 32)) & ((1 << 6) - 1);
    if (coarse == 0x3f) coarse = 0x1f;
    SYSCTRL->DFLLVAL.bit.COARSE = coarse;
    SYSCTRL->DFLLVAL.bit.FINE = 0x1ff;

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

    SystemCoreClock = F_CPU;
}

extern uint32_t __etext, __data_start__, __data_end__, __bss_start__, __bss_end__, __StackTop;

__attribute__((used, section(".isr_vector")))
const DeviceVectors exception_table = {
    (void *)(&__StackTop), (void *)Reset_Handler, (void *)NMI_Handler,
    (void *)HardFault_Handler, 0, 0, 0, 0, 0, 0, 0, (void *)SVC_Handler, 0, 0,
    (void *)PendSV_Handler, (void *)SysTick_Handler, (void *)PM_Handler,
    (void *)SYSCTRL_Handler, (void *)WDT_Handler, (void *)RTC_Handler,
    (void *)EIC_Handler, (void *)NVMCTRL_Handler, (void *)DMAC_Handler,
    (void *)USB_Handler, (void *)EVSYS_Handler, (void *)SERCOM0_Handler,
    (void *)SERCOM1_Handler, (void *)SERCOM2_Handler, (void *)SERCOM3_Handler,
    (void *)SERCOM4_Handler, (void *)SERCOM5_Handler, (void *)TCC0_Handler,
    (void *)TCC1_Handler, (void *)TCC2_Handler, (void *)TC3_Handler,
    (void *)TC4_Handler, (void *)TC5_Handler, (void *)TC6_Handler,
    (void *)TC7_Handler, (void *)ADC_Handler, (void *)AC_Handler,
    (void *)DAC_Handler, (void *)PTC_Handler, (void *)I2S_Handler, 0,
};

void Reset_Handler(void) {
    uint32_t *src = &__etext, *dst = &__data_start__;
    for (; dst < &__data_end__; dst++, src++) *dst = *src;
    for (dst = &__bss_start__; dst < &__bss_end__; dst++) *dst = 0;
    clock_init();
    app_init();
    for (;;) app_main();
}
