// Reset, vector table, main, and 1 ms SysTick for millis().

#include <sam.h>
#include <stdint.h>

uint32_t SystemCoreClock = 1000000ul;

extern void SystemInit(void);
extern void app_init(void);
extern void app_main(void);

static volatile uint32_t g_millis;

static void systick_init(void) {
    if (SysTick_Config(SystemCoreClock / 1000u)) {
        for (;;)
            ;
    }
}

unsigned long millis(void) { return g_millis; }

void SysTick_Handler(void) { g_millis++; }

static void Dummy_Handler(void) {
    for (;;)
        ;
}

void HardFault_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void Reset_Handler(void);
void NMI_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SVC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void PendSV_Handler(void) __attribute__((weak, alias("Dummy_Handler")));

void PM_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SYSCTRL_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void WDT_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void RTC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void EIC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void NVMCTRL_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void DMAC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void USB_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void EVSYS_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SERCOM0_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SERCOM1_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SERCOM2_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SERCOM3_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SERCOM4_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void SERCOM5_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TCC0_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TCC1_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TCC2_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TC3_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TC4_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TC5_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TC6_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void TC7_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void ADC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void AC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void DAC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void PTC_Handler(void) __attribute__((weak, alias("Dummy_Handler")));
void I2S_Handler(void) __attribute__((weak, alias("Dummy_Handler")));

extern uint32_t __etext;
extern uint32_t __data_start__;
extern uint32_t __data_end__;
extern uint32_t __bss_start__;
extern uint32_t __bss_end__;
extern uint32_t __StackTop;

__attribute__((used, section(".isr_vector")))
const DeviceVectors exception_table = {
    (void *)(&__StackTop),
    (void *)Reset_Handler,
    (void *)NMI_Handler,
    (void *)HardFault_Handler,
    (void *)(0UL), (void *)(0UL), (void *)(0UL), (void *)(0UL),
    (void *)(0UL), (void *)(0UL), (void *)(0UL),
    (void *)SVC_Handler,
    (void *)(0UL), (void *)(0UL),
    (void *)PendSV_Handler,
    (void *)SysTick_Handler,
    (void *)PM_Handler,
    (void *)SYSCTRL_Handler,
    (void *)WDT_Handler,
    (void *)RTC_Handler,
    (void *)EIC_Handler,
    (void *)NVMCTRL_Handler,
    (void *)DMAC_Handler,
    (void *)USB_Handler,
    (void *)EVSYS_Handler,
    (void *)SERCOM0_Handler,
    (void *)SERCOM1_Handler,
    (void *)SERCOM2_Handler,
    (void *)SERCOM3_Handler,
    (void *)SERCOM4_Handler,
    (void *)SERCOM5_Handler,
    (void *)TCC0_Handler,
    (void *)TCC1_Handler,
    (void *)TCC2_Handler,
    (void *)TC3_Handler,
    (void *)TC4_Handler,
    (void *)TC5_Handler,
    (void *)TC6_Handler,
    (void *)TC7_Handler,
    (void *)ADC_Handler,
    (void *)AC_Handler,
    (void *)DAC_Handler,
    (void *)PTC_Handler,
    (void *)I2S_Handler,
    (void *)(0UL),
};

void Reset_Handler(void) {
    uint32_t *src = &__etext;
    uint32_t *dst = &__data_start__;

    if ((&__data_start__ != &__data_end__) && (src != dst)) {
        for (; dst < &__data_end__; dst++, src++) {
            *dst = *src;
        }
    }

    for (dst = &__bss_start__; dst < &__bss_end__; dst++) {
        *dst = 0;
    }

    SystemInit();
    systick_init();
    app_init();

    for (;;) {
        app_main();
    }
}
