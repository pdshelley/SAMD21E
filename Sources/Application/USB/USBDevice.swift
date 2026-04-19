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

// MARK: - Milestone 1: Clock & Power (stub)
// TODO: Configure OSC8M → GCLK0, enable DFLL48M open-loop, switch GCLK0 to DFLL48M,
//       route DFLL48M to USB peripheral via GenericClockController,
//       enable USB APB + AHB clocks via PowerManager.

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
