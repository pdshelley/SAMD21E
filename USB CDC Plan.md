# USB CDC Development Plan

## Overview

A layered, incremental plan for building a USB CDC-ACM driver on the SAMD21E (bare-metal Swift,
no stdlib, no heap, CRYSTALLESS board). Each milestone produces something verifiable on hardware
before the next begins. A Saleae logic analyzer can assist at every stage.

---

## Architecture

```
Application (Application.swift)
    │
    ▼
USBCDC              (Sources/Application/USB/USBCDC.swift)
    │
    ▼
USBDevice           (Sources/Application/USB/USBDevice.swift)
    │
    ├── USB HAL             (Sources/SAMD21/module/USB.swift)
    ├── GenericClockController  (Sources/SAMD21/module/GenericClockController.swift)
    ├── PowerManager            (Sources/SAMD21/module/PowerManager.swift)
    ├── SystemController        (Sources/SAMD21/module/SystemController.swift)
    └── NonvolatileMemoryController (Sources/SAMD21/module/NonvolatileMemoryController.swift)
```

**USBDescriptors** (`Sources/Application/USB/USBDescriptors.swift`) is a supporting file with
all descriptor byte arrays stored in flash, accessed by USBDevice's SETUP handler.

### Layer responsibilities

| File | Responsibility |
|---|---|
| `USBDevice` | HAL orchestration, clock/power init, descriptor table, EP0 state machine, device lifecycle |
| `USBDescriptors` | All descriptor bytes (device, config, CDC, strings) as flash-resident constants |
| `USBCDC` | CDC class: bulk endpoints, TX/RX ring buffers, line coding requests |

---

## Architecture Notes

### NVM factory calibration
The SAMD21 stores USB pad calibration values (TRANSP, TRANSN, TRIM) in the NVM Software
Calibration Area at `0x806020`. These **must** be read and written to `USB.PADCAL` during
init or the USB PHY may be unreliable. Read via `NonvolatileMemoryController` using its
calibration row accessors.

> Datasheet ref: Section 9.5 (NVM Software Calibration Area), Section 32.6.2 (PADCAL).

### CRYSTALLESS clock strategy
No external crystal is present. The DFLL48M must supply the USB 48 MHz clock.

Two-phase approach:
1. **Before enumeration:** DFLL48M in open-loop mode (free-running ≈48 MHz). Accuracy is
   sufficient to start USB enumeration.
2. **After first SOF packet received:** Enable USB Clock Recovery Mode (`SystemController.
   dfllUSBClockRecoveryMode = true`). The DFLL48M phase-locks to incoming SOF pulses from
   the host, achieving the accuracy required by the USB spec.

### Polling-first, interrupts later
For bring-up, poll INTFLAG registers directly (no NVIC enable needed). Interrupt-driven
operation is added in Milestone 7 once the data path is proven.

### Descriptor table lifetime
The 256-byte descriptor table (8 endpoints × 2 banks × 16 bytes) must live in persistent
SRAM — not on any function's stack. Declare it as a module-level stored variable in
`USBDevice.swift`.

---

## Milestones

---

### Milestone 1 — Clock & Power Initialization ✓ COMPLETE

**Goal:** DFLL48M running at 48 MHz in open-loop mode, routed to the USB peripheral. LED blinking at 1 Hz.

**Files:** `USBDevice.swift` — `usbClockInit()` function

**Verified:** LED blinks correctly at 1 Hz. No hard fault.

**Key findings from implementation (update future session prompts with these):**

`startup.c` / `SystemInit()` runs before Swift and leaves the system in a specific state:
- OSC8M prescaler already ÷1 (8 MHz)
- GCLK0 already sourced from DFLL48M (CPU already at 48 MHz)
- DFLL48M already enabled — but **in USBCRM closed-loop mode** (MODE=1, USBCRM=1, CCDIS=1, BPLCKC=1)

The USBCRM state is the critical issue: enabling the USB AHB clock while DFLL is still in
USBCRM causes the DFLL to respond to noise on D+/D− as false SOF events, destabilising the
system clock and hanging the CPU.

**Actual 6-step sequence implemented:**

| Step | Action | Status |
|------|--------|--------|
| 1 | OSC8M ÷1 | Idempotent — startup.c already did this |
| 2 | GCLK0 → OSC8M | **Required** — stable CPU clock while DFLL is reconfigured |
| 3 | Disable DFLL → re-enable open-loop only | **Required** — clears USBCRM/MODE left by startup.c |
| 4 | GCLK0 → DFLL48M | Idempotent — same as startup.c, but needed after step 2 |
| 5 | CLKCTRL: USB peripheral → GEN0 | **Required** — startup.c never touched USB clock routing |
| 6 | Enable USB APB + AHB clocks | **Required** — startup.c never touched USB PM clocks |

**Correction to original plan:** SYNCBUSY **is** required after CLKCTRL writes.
`startup.c` line 98 confirms this. The original plan summary was wrong on this point.

---

### Milestone 2 — USB Peripheral Initialization & Bus Attach

**Goal:** USB device appears on host (unknown device, no descriptors yet — but host sees connection).

**Files:** `USBDevice.swift`

**Implementation steps:**
1. Read NVM factory calibration via `NonvolatileMemoryController` calibration row accessors:
   - TRANSP, TRANSN, TRIM — write to `USB.PADCAL`.
2. Allocate 256-byte descriptor table at module scope (16-byte aligned).
3. Write descriptor table address to `USB.DESCADD`.
4. Set `USB.mode = .device`.
5. Enable USB: `USB.enable = true`, wait SYNCBUSY.
6. Pulse DETACH: set `USB.detach = true`, delay ≥1 ms, clear `USB.detach = false`.

**Critical detail:** Descriptor table buffer must be module-level (persistent SRAM), not a
local variable of any init function.

**Verification:**
- macOS: `system_profiler SPUSBDataType` shows a new unknown device → PHY and attach OK.
- Logic analyzer: D+ line goes high (1.5 kΩ pull-up, full-speed device), host begins reset.

---

### Milestone 3 — EP0 & Basic Control Transfer (SETUP handling)

**Goal:** Device responds to GET_DESCRIPTOR with a placeholder Device Descriptor. Host shows VID/PID.

**Files:** `USBDevice.swift`

**Implementation steps:**
1. Configure EP0 in descriptor table: Bank0 type = `.control`, Bank1 = `.control`,
   packet size = 64 bytes.
2. Allocate EP0 RX/TX buffers (64 bytes each) at module scope.
3. Write EP0 bank buffer addresses into descriptor table entries.
4. Poll loop:
   - `USB.INTFLAG.EORST` set → re-configure EP0, clear flag.
   - `USB.EP[0].EPINTFLAG.RXSTP` set → read 8-byte SETUP packet from EP0 Bank0 buffer, dispatch.
5. Handle `GET_DESCRIPTOR` for Device Descriptor (18-byte placeholder: VID=0x239A, PID=0x0001).
6. Handle `SET_ADDRESS` → write address to `USB.DADD`, set ADDEN bit.
7. Handle `SET_CONFIGURATION` → stub ACK (STATUS IN phase only).

**EP0 state machine states:** `idle`, `dataIn`, `dataOut`, `statusIn`, `statusOut`

**Verification:**
- macOS: `system_profiler SPUSBDataType` shows device with VID 0x239A, PID 0x0001.
- "Device not recognized" or "Unknown Device" is expected and acceptable at this stage.
- Logic analyzer: confirm SETUP → DATA IN → STATUS OUT phase sequence on D+/D-.

---

### Milestone 4 — CDC Descriptors & Full Enumeration

**Goal:** Host enumerates as CDC device. macOS loads CDC driver. `/dev/cu.usbmodem*` appears.

**Files:** `USBDescriptors.swift` (new), `USBDevice.swift` (descriptor serving + EP1/EP2 setup)

**Descriptor structure (`USBDescriptors.swift`):**
- Device Descriptor: class=0x02, subclass=0, protocol=0, VID/PID final values.
- Configuration Descriptor block (concatenated, wTotalLength must be exact):
  - Configuration Descriptor (9 bytes)
  - Interface 0: CDC Communication (class=0x02, subclass=0x02 ACM, protocol=0x01 AT-commands)
    - CDC Header Functional Descriptor (5 bytes)
    - CDC Call Management Functional Descriptor (5 bytes)
    - CDC ACM Functional Descriptor (4 bytes)
    - CDC Union Functional Descriptor (5 bytes)
    - Endpoint 1 IN: Interrupt, 8 bytes, bInterval=255
  - Interface 1: CDC Data (class=0x0A, subclass=0, protocol=0)
    - Endpoint 2 OUT: Bulk, 64 bytes
    - Endpoint 2 IN: Bulk, 64 bytes
- String Descriptors: index 0 = LangID 0x0409, index 1 = Manufacturer, index 2 = Product,
  index 3 = Serial Number.

**`USBDevice.swift` additions:**
- Expose `descriptor(type:index:)` returning pointer + length into the above arrays.
- On `SET_CONFIGURATION`: configure EP1 and EP2 banks in descriptor table.
- Allocate EP1 and EP2 data buffers at module scope.

**Verification:**
- macOS: `/dev/cu.usbmodem*` appears in `/dev/`.
- `screen /dev/cu.usbmodem* 115200` opens without immediate error.
- Logic analyzer: confirm descriptor exchange, SET_ADDRESS, SET_CONFIGURATION sequence.

---

### Milestone 5 — CDC Bulk Data Transfer

**Goal:** Text typed in a host terminal echoes back. Bidirectional bulk transfer proven.

**Files:** `USBCDC.swift` (new)

**Implementation steps:**
1. 256-byte circular TX ring buffer and 256-byte RX ring buffer at module scope.
2. EP2 OUT (RX from host): poll `EPINTFLAG.TRCPT0` — when set, copy data from EP2 Bank0
   buffer into RX ring, clear BK0RDY to re-arm the bank.
3. EP2 IN (TX to host): when TX ring is non-empty and BK1RDY is clear, copy ≤64 bytes
   into EP2 Bank1 buffer, set BK1RDY.
4. Public API:
   - `write(_ bytes: [UInt8])`
   - `read() -> UInt8?`
   - `available() -> Int`
5. Echo test in `Application.swift`: read bytes, write them back.

**Verification:**
- `screen /dev/cu.usbmodem* 115200` — typed characters echo.
- Test with multi-byte strings (>64 bytes) to exercise multi-packet paths.
- Logic analyzer: confirm bulk OUT → bulk IN packet pairs.

---

### Milestone 6 — CDC Class Requests & Line Coding

**Goal:** Standard terminal programs (screen, minicom, Arduino Serial Monitor) work correctly.

**Files:** `USBCDC.swift`

**Implementation steps:**
1. `SET_LINE_CODING`: parse 7-byte LineCoding struct (baud, stopBits, parity, dataBits).
   Store values. ACK with zero-length STATUS IN.
2. `GET_LINE_CODING`: return stored LineCoding struct in DATA IN phase.
3. `SET_CONTROL_LINE_STATE`: parse DTR (bit 0) and RTS (bit 1). Store. ACK.
4. EP1 IN (notification endpoint): send 10-byte `SERIAL_STATE` notification header +
   2-byte wSerialState when connection state changes (DTR asserted by host).

**Verification:**
- Arduino Serial Monitor connects without errors.
- VS Code Serial Monitor connects without errors.
- Send/receive large blocks across multiple bulk packets without corruption.

---

### Milestone 7 — Interrupt-Driven Operation (Optional)

**Goal:** Replace polling loops with USB ISR. Main loop is free for application work.

**Files:** `USBDevice.swift`, `USBCDC.swift`, `startup.c` (or equivalent vector table)

**Implementation steps:**
1. Identify USB interrupt vector slot in `startup.c` / cortex_handlers file.
2. Define `@_cdecl("USB_Handler")` Swift function (or C stub).
3. Enable USB NVIC interrupt (write to NVIC ISER register at 0xE000E100).
4. Move INTFLAG polling from poll loop into ISR.
5. Use `volatile` flags (or a small event queue) to communicate from ISR to main loop.
6. Ensure all shared state (ring buffers, EP state) is `volatile` or access is
   protected by temporarily disabling the USB interrupt.

**Verification:**
- Main loop can blink LED at a steady rate while USB CDC continues to function.
- No data corruption under load (send large file while LED blinks).

---

## Verification Tools

| Tool | What it shows |
|---|---|
| `system_profiler SPUSBDataType` | Device presence, VID/PID, class, enumeration state |
| `/dev/cu.usbmodem*` | macOS CDC driver loaded successfully |
| `screen /dev/cu.usbmodem* 115200` | Bidirectional data transfer |
| Saleae logic analyzer (D+/D-) | Bus reset, SETUP packets, data phases, SOF timing |
| Saleae USB protocol decoder | Enumerate descriptor exchange, class requests |
| LED blink rate | Clock sanity (M1), ISR vs. main loop coexistence (M7) |

---

## Session Strategy

Use **one fresh Claude session per milestone**. This session (or a notes document) serves
as the coordination layer:
- Confirm milestone verification passes on hardware.
- Adjust next milestone spec if hardware revealed unexpected constraints.
- Open fresh session, provide: milestone spec + current file contents + HAL files.

Each implementation session prompt should include:
1. The milestone goal and steps from this document.
2. Full content of: `USB.swift`, `GenericClockController.swift`, `PowerManager.swift`,
   `SystemController.swift`, `NonvolatileMemoryController.swift`.
3. Current state of all files in `Sources/Application/USB/`.
4. Verification criteria.
5. Constraints: no stdlib, no heap, embedded Swift, polling-first (until M7).
