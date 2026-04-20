#include "tusb.h"

// Overrides the weak Dummy_Handler alias in cortex_handlers.c.
// TinyUSB processes all USB events inside tud_int_handler.
void USB_Handler(void) {
    tud_int_handler(0);
}
