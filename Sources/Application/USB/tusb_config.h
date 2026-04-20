#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// SAMD21 on port 0
#define CFG_TUSB_MCU            OPT_MCU_SAMD21
#define CFG_TUSB_OS             OPT_OS_NONE
#define CFG_TUSB_DEBUG          0

// 4-byte alignment is required for USB DMA descriptors on SAMD21
#define CFG_TUSB_MEM_SECTION
#define CFG_TUSB_MEM_ALIGN      __attribute__((aligned(4)))

// Tell tusb_init() which port to initialize as a device.
// Without this TUD_OPT_RHPORT is undefined and tusb_init() is a no-op.
#define CFG_TUSB_RHPORT0_MODE   (OPT_MODE_DEVICE | OPT_MODE_FULL_SPEED)

// Device-mode only; full-speed (SAMD21 has no HS PHY)
#define CFG_TUD_ENABLED         1
#define CFG_TUD_MAX_SPEED       OPT_MODE_FULL_SPEED
#define CFG_TUD_ENDPOINT0_SIZE  64

// CDC ACM: one interface
#define CFG_TUD_CDC             1
#define CFG_TUD_CDC_RX_BUFSIZE  64
#define CFG_TUD_CDC_TX_BUFSIZE  64
#define CFG_TUD_CDC_EP_BUFSIZE  64

// All other device classes disabled
#define CFG_TUD_MSC             0
#define CFG_TUD_HID             0
#define CFG_TUD_MIDI            0
#define CFG_TUD_VENDOR          0

#ifdef __cplusplus
}
#endif
