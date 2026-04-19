/// USBDevice — application-layer orchestration for the SAMD21 USB peripheral.
///
/// Responsibilities:
///   - Clock and power initialization (DFLL48M, GenericClockController, PowerManager)
///   - USB peripheral bring-up and pad calibration
///   - Descriptor table management (SRAM-resident, 16-byte aligned)
///   - Endpoint 0 control transfer state machine (SETUP / DATA / STATUS)
///   - Device lifecycle: attach, reset, suspend, resume
///   - Routing incoming class/vendor requests to registered handlers
///
/// Not responsible for:
///   - CDC-specific logic (see USBCDC.swift)
///   - Descriptor content (see USBDescriptors.swift)
///
/// Milestone coverage: M1 (clock/power), M2 (init/attach), M3 (EP0 control transfers),
///                     M4 (descriptor serving), M7 (interrupt-driven upgrade)


// MARK: - Milestone 1: Clock & Power

/// Reconfigure clocks and power for the USB peripheral.
///
/// `startup.c` / `SystemInit()` leaves DFLL48M running in USBCRM (USB Clock Recovery Mode),
/// locked to USB SOF pulses.  This is unsafe before the USB peripheral is fully initialised:
/// enabling the USB AHB clock while USBCRM is active can make the DFLL react to noise on
/// D+/D− as false SOF events, destabilising the system clock.
///
/// Full 6-step sequence (mirrors the startup.c DFLL reconfiguration pattern):
///   1. OSC8M prescaler = ÷1 → 8 MHz stable reference (idempotent; startup.c already did this).
///   2. Switch GCLK0 source to OSC8M so the CPU has a stable clock while DFLL is reconfigured.
///   3. Disable DFLL48M (write 0 to DFLLCTRL), wait for DFLLRDY, then re-enable in open-loop
///      mode only (ENABLE=1, all other bits 0 → USBCRM/MODE/CCDIS/BPLCKC all cleared).
///   4. Switch GCLK0 back to DFLL48M (open-loop ≈ 48 MHz).  CPU clock restored.
///   5. Route GCLK0 to the USB peripheral clock input (GCLK.CLKCTRL, ID=USB, GEN=0, CLKEN=1).
///   6. Enable USB APB clock (PM.APBBMASK) and AHB clock (PM.AHBMASK).
///
/// SYNCBUSY must be awaited after every GENCTRL and GENDIV write, and also after CLKCTRL
/// writes (SAMD21 datasheet §15.6.4; startup.c confirms this practice at line 98).
func usbClockInit() {

    // Step 1: OSC8M prescaler = ÷1 → 8 MHz (idempotent)
    SystemController.osc8MPrescaler = .div1

    // Step 2: Switch GCLK0 → OSC8M so the CPU is on a stable clock before DFLL is touched.
    //
    // GENDIV = 0x00000000
    //   Bits [3:0]  ID  = 0  (Generator 0)
    //   Bits [23:8] DIV = 0  (÷1, no division)
    GenericClockController.generatorDivision = 0x00000000
    while GenericClockController.synchronizationBusy {}

    // GENCTRL = 0x00010600
    //   Bits [3:0]   ID    = 0x0  (Generator 0)
    //   Bits [12:8]  SRC   = 0x06 (OSC8M)
    //   Bit  [16]    GENEN = 1    (enable generator)
    GenericClockController.generatorControl = 0x00010600
    while GenericClockController.synchronizationBusy {}

    // Step 3: Reconfigure DFLL48M from USBCRM (closed-loop) to open-loop.
    //
    // Disable by writing 0 to all of DFLLCTRL, then wait for DFLLRDY (hardware clears
    // DFLLRDY momentarily on any DFLLCTRL write, then sets it again when settled —
    // the same pattern startup.c uses at lines 132–134).
    SystemController.dfllControlRegister = 0x0000
    while !SystemController.dfllReadyStatus {}

    // Re-enable with ENABLE=1 only: open-loop mode, USBCRM/MODE/CCDIS/BPLCKC all cleared.
    SystemController.dfllEnable = true
    while !SystemController.dfllReadyStatus {}

    // Step 4: Switch GCLK0 back to DFLL48M → CPU restored to ≈ 48 MHz.
    //
    // GENDIV = 0x00000000  (GEN0, DIV=0, ÷1)
    GenericClockController.generatorDivision = 0x00000000
    while GenericClockController.synchronizationBusy {}

    // GENCTRL = 0x00030700
    //   Bits [3:0]   ID    = 0x0  (Generator 0)
    //   Bits [12:8]  SRC   = 0x07 (DFLL48M)
    //   Bit  [16]    GENEN = 1    (enable generator)
    //   Bit  [17]    IDC   = 1    (50/50 duty cycle for all division factors)
    GenericClockController.generatorControl = 0x00030700
    while GenericClockController.synchronizationBusy {}

    // Step 5: Route GCLK0 (DFLL48M ≈ 48 MHz) to the USB peripheral clock input.
    //
    // CLKCTRL = 0x4006
    //   Bits [5:0]  ID    = 0x06 (USB peripheral clock input)
    //   Bits [11:8] GEN   = 0x00 (Generator 0)
    //   Bit  [14]   CLKEN = 1    (enable clock to peripheral)
    GenericClockController.clockControlRegister = 0x4006
    while GenericClockController.synchronizationBusy {}

    // Step 6: Enable USB APB clock (PM.APBBMASK bit 5) and AHB clock (PM.AHBMASK bit 6).
    PowerManager.usbClockEnable = true
    PowerManager.usbAHBClockEnable = true
}


// MARK: - Milestone 2: USB Peripheral Init (stub)
// TODO: Read NVM factory calibration at 0x806020 for TRANSP/TRANSN/TRIM, write to USB.PADCAL.
//       Allocate 256-byte descriptor table (16-byte aligned, module-level storage).
//       Write address to USB.DESCADD. Set mode=device, enable, pulse DETACH.

// MARK: - Milestone 3: EP0 Control Transfer State Machine (stub)
// TODO: Configure EP0 Bank0/Bank1 as .control with 64-byte packet size.
//       Allocate EP0 RX/TX buffers (64 bytes each, module-level storage).
//       Poll loop: EORST → re-configure EP0; RXSTP → read SETUP packet, dispatch.
//       Handle: GET_DESCRIPTOR, SET_ADDRESS, SET_CONFIGURATION (stub ACK).
//       EP0 states: idle, dataIn, dataOut, statusIn, statusOut.
