#include "tusb.h"

// VID/PID — 0xCafe is TinyUSB's example vendor; PID bit 0 = CDC
#define USB_VID   0xCafe
#define USB_PID   0x4001
#define USB_BCD   0x0200

// ---------------------------------------------------------------------------
// Device descriptor
// ---------------------------------------------------------------------------

tusb_desc_device_t const desc_device = {
    .bLength            = sizeof(tusb_desc_device_t),
    .bDescriptorType    = TUSB_DESC_DEVICE,
    .bcdUSB             = USB_BCD,

    // Use IAD (Interface Association Descriptor) as required when CDC is present
    .bDeviceClass       = TUSB_CLASS_MISC,
    .bDeviceSubClass    = MISC_SUBCLASS_COMMON,
    .bDeviceProtocol    = MISC_PROTOCOL_IAD,

    .bMaxPacketSize0    = CFG_TUD_ENDPOINT0_SIZE,
    .idVendor           = USB_VID,
    .idProduct          = USB_PID,
    .bcdDevice          = 0x0100,

    .iManufacturer      = 0x01,
    .iProduct           = 0x02,
    .iSerialNumber      = 0x03,

    .bNumConfigurations = 0x01,
};

uint8_t const *tud_descriptor_device_cb(void) {
    return (uint8_t const *)&desc_device;
}

// ---------------------------------------------------------------------------
// Configuration descriptor — one CDC ACM interface
// ---------------------------------------------------------------------------

enum {
    ITF_NUM_CDC = 0,
    ITF_NUM_CDC_DATA,
    ITF_NUM_TOTAL,
};

#define EPNUM_CDC_NOTIF   0x81  // EP1 IN  — interrupt (notification)
#define EPNUM_CDC_OUT     0x02  // EP2 OUT — bulk (host → device)
#define EPNUM_CDC_IN      0x82  // EP2 IN  — bulk (device → host)

#define CONFIG_TOTAL_LEN  (TUD_CONFIG_DESC_LEN + TUD_CDC_DESC_LEN)

static uint8_t const desc_configuration[] = {
    // Config number, interface count, string index, total length, attributes, power (mA)
    TUD_CONFIG_DESCRIPTOR(1, ITF_NUM_TOTAL, 0, CONFIG_TOTAL_LEN, 0x00, 100),

    // Interface number, string index, notification EP + size, data EP out/in + size
    TUD_CDC_DESCRIPTOR(ITF_NUM_CDC, 4, EPNUM_CDC_NOTIF, 8, EPNUM_CDC_OUT, EPNUM_CDC_IN, 64),
};

uint8_t const *tud_descriptor_configuration_cb(uint8_t index) {
    (void)index;
    return desc_configuration;
}

// ---------------------------------------------------------------------------
// String descriptors
// ---------------------------------------------------------------------------

enum {
    STRID_LANGID = 0,
    STRID_MANUFACTURER,
    STRID_PRODUCT,
    STRID_SERIAL,
    STRID_CDC_ITF,
};

static char const *string_desc_arr[] = {
    (const char[]){ 0x09, 0x04 },   // 0: Language — English (0x0409)
    "Embedded Swift",               // 1: Manufacturer
    "SAMD21E CDC",                  // 2: Product
    "001",                          // 3: Serial number
    "CDC Serial",                   // 4: CDC interface name
};

static uint16_t _desc_str[32 + 1];

uint16_t const *tud_descriptor_string_cb(uint8_t index, uint16_t langid) {
    (void)langid;

    size_t chr_count;

    if (index == STRID_LANGID) {
        __builtin_memcpy(&_desc_str[1], string_desc_arr[0], 2);
        chr_count = 1;
    } else {
        if (index >= sizeof(string_desc_arr) / sizeof(string_desc_arr[0])) return NULL;

        const char *str = string_desc_arr[index];
        chr_count = 0;
        while (str[chr_count] && chr_count < 32) chr_count++;

        for (size_t i = 0; i < chr_count; i++) {
            _desc_str[1 + i] = str[i];
        }
    }

    _desc_str[0] = (uint16_t)((TUSB_DESC_STRING << 8) | (2 * chr_count + 2));
    return _desc_str;
}
