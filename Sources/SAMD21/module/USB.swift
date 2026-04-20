//
//  USB.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/19/26.
//

//  Low-level register map for the SAMD21 USB peripheral.
//  TinyUSB owns this peripheral at runtime — do not call these directly
//  while CDC is active. Use the CDC module in Sources/SAMD21/module/CDC.swift.

@usableFromInline let USB_BASE: UInt    = 0x41005000   // SAMD21 datasheet §32.8
@usableFromInline let USB_EP_BASE: UInt = 0x41005100   // §32.8 – endpoint/pipe register array

/// Universal Serial Bus Controller
///
/// The USB peripheral supports both Device and Host modes. Many registers occupy the
/// same address offset but have different bit definitions depending on the active mode
/// (selected by CTRLA.MODE). Bit-field properties are grouped and prefixed with
/// `device` or `host` accordingly.
///
/// Endpoint (device) and pipe (host) registers are indexed 0–7. They are accessed
/// through functions that take an index rather than separate per-endpoint properties.
///
/// The SRAM descriptor table (pointed to by `descriptorAddress`) is a contiguous array
/// of bank descriptors allocated by the application. Each endpoint/pipe occupies two
/// 16-byte entries (bank 0 and bank 1). The layout per bank is:
///
/// ```
///   Offset  Field        Width  Description
///   0x00    ADDR         32     Data buffer base address in SRAM.
///   0x04    PCKSIZE      32     [13:0]  BYTE_COUNT  – bytes transferred.
///                               [27:14] MULTI_PACKET_SIZE – target byte count.
///                               [30:28] SIZE        – max packet size (see PacketSize).
///                               [31]    AUTO_ZLP    – send zero-length packet automatically.
///   0x08    EXTREG       16     Host bank 0 only: [3:0] SUBPID, [15:4] VARIABLE.
///   0x0A    STATUS_BK    8      Host only: [0] CRCERR, [1] ERRORFLOW.
/// ```
///
/// APB clock must be enabled via `PowerManager.usbClockEnable` before accessing registers.
/// A generic clock (usually GCLK0 at 48 MHz) must be routed to USB via
/// `GenericClockController`.
///
/// See SAMD21 datasheet Section 32.
struct USB {

    // MARK: - Supporting Enums

    /// USB operating mode (CTRLA.MODE).
    enum Mode: UInt32 {
        case device = 0
        case host   = 1
    }

    /// Quality-of-Service level (QOSCTRL.CQOS / QOSCTRL.DQOS).
    enum QoSLevel: UInt32 {
        case background = 0   ///< Lowest priority.
        case sensitive  = 1
        case reserved   = 2
        case critical   = 3   ///< Highest priority.
    }

    // MARK: Device-mode enums

    /// Device-mode speed configuration (device CTRLB.SPDCONF).
    enum DeviceSpeedConfig: UInt32 {
        case fullSpeed        = 0   ///< Normal full-speed (12 Mbps). Default.
        case lowSpeed         = 1   ///< Low-speed (1.5 Mbps).
        case highSpeed        = 2   ///< Not supported on SAMD21; reserved.
        case highSpeedTest    = 3   ///< High-speed test mode (forces full-speed).
    }

    /// LPM handshake response (device CTRLB.LPMHDSK).
    enum LPMHandshake: UInt32 {
        case noHandshake = 0   ///< LPM request silently ignored.
        case ack         = 1   ///< ACK — device enters L1 sleep.
        case nyet        = 2   ///< NYET — not ready to enter L1.
        case stall       = 3   ///< STALL — LPM not supported.
    }

    /// Device speed reported in STATUS.SPEED after reset.
    enum DeviceSpeed: UInt32 {
        case fullSpeed = 0   ///< 12 Mbps.
        case highSpeed = 1   ///< Not available on SAMD21.
        case lowSpeed  = 2   ///< 1.5 Mbps.
    }

    /// USB data line state (device STATUS.LINESTATE).
    enum LineState: UInt32 {
        case se0         = 0   ///< Single-ended zero; both lines low.
        case fsOrLsJ     = 1   ///< Full- or low-speed J state.
        case fsOrLsK     = 2   ///< Full- or low-speed K state.
        case undefined   = 3
    }

    /// Device endpoint bank type (EPCFG.EPTYPE0 / EPTYPE1).
    ///
    /// Bank 0 carries OUT (host-to-device) traffic; bank 1 carries IN (device-to-host) traffic.
    /// For a control endpoint configure both banks as `.control`.
    enum EndpointBankType: UInt32 {
        case disabled    = 0
        case control     = 1
        case isochronous = 2
        case bulk        = 3
        case interrupt   = 4
        case dualBank    = 5
    }

    // MARK: Host-mode enums

    /// Host-mode speed configuration (host CTRLB.SPDCONF).
    enum HostSpeedConfig: UInt32 {
        case normal        = 0   ///< Auto-detect device speed. Default.
        case fullSpeed     = 1   ///< Force full-speed.
        case highSpeed     = 2   ///< Not supported on SAMD21; reserved.
        case highSpeedTest = 3   ///< High-speed test mode.
    }

    /// Host pipe token type (PCFG.PTOKEN).
    enum PipeToken: UInt32 {
        case setup    = 0
        case `in`     = 1
        case out      = 2
    }

    /// Host pipe type (PCFG.PTYPE).
    enum PipeType: UInt32 {
        case disabled    = 0
        case control     = 1
        case isochronous = 2
        case bulk        = 3
        case interrupt   = 4
        case extended    = 5
    }

    /// Max packet size encoding used in the SRAM descriptor PCKSIZE.SIZE field.
    enum PacketSize: UInt32 {
        case bytes8    = 0
        case bytes16   = 1
        case bytes32   = 2
        case bytes64   = 3
        case bytes128  = 4
        case bytes256  = 5
        case bytes512  = 6
        case bytes1023 = 7   ///< Maximum for isochronous endpoints.
    }


    // MARK: - CTRLA – Control A (Offset 0x00, 8-bit, common)
    //
    // Shared 32-bit word layout at USB_BASE + 0x00:
    //   [7:0]   = CTRLA
    //   [15:8]  = reserved
    //   [23:16] = SYNCBUSY (read-only)
    //   [31:24] = QOSCTRL

    /// CTRLA – Control A Register
    /// See Section 32.8.1.
    ///
    /// Controls the software reset, enable, standby, and mode of the USB peripheral.
    /// Writing SWRST while ENABLE is set resets all registers to their reset values.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  7  | MODE    | R/W | '0' = Device, '1' = Host.                     |
    /// -----------------------------------------------------------------------
    /// |  2  | RUNSTDBY| R/W | Run in Standby.                               |
    /// -----------------------------------------------------------------------
    /// |  1  | ENABLE  | R/W | USB Enable. Wait for SYNCBUSY.ENABLE to clear.|
    /// -----------------------------------------------------------------------
    /// |  0  | SWRST   | R/W | Software Reset. Wait for SYNCBUSY.SWRST.      |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var controlARegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x00) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x00)
            _volatileRegisterWriteUInt32(USB_BASE + 0x00, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// CTRLA.SWRST – Software Reset
    @inline(__always)
    static var softwareReset: Bool {
        get { (controlARegister & (1 << 0)) != 0 }
        set {
            controlARegister = newValue
                ? (controlARegister | (1 << 0))
                : (controlARegister & ~(1 << 0))
        }
    }

    /// CTRLA.ENABLE – USB Enable
    @inline(__always)
    static var enable: Bool {
        get { (controlARegister & (1 << 1)) != 0 }
        set {
            controlARegister = newValue
                ? (controlARegister | (1 << 1))
                : (controlARegister & ~(1 << 1))
        }
    }

    /// CTRLA.RUNSTDBY – Run in Standby
    @inline(__always)
    static var runInStandby: Bool {
        get { (controlARegister & (1 << 2)) != 0 }
        set {
            controlARegister = newValue
                ? (controlARegister | (1 << 2))
                : (controlARegister & ~(1 << 2))
        }
    }

    /// CTRLA.MODE – Operating Mode
    @inline(__always)
    static var mode: Mode {
        get {
            let m = (controlARegister >> 7) & 0x01
            return Mode(rawValue: m) ?? .device
        }
        set {
            controlARegister = (controlARegister & ~(0x01 << 7)) | ((newValue.rawValue & 0x01) << 7)
        }
    }


    // MARK: - SYNCBUSY – Synchronization Busy (Offset 0x02, 8-bit, read-only, common)

    /// SYNCBUSY – Synchronization Busy Register
    /// See Section 32.8.2.
    ///
    /// Bits are set while a register synchronization write is in progress.
    /// Poll the relevant bit before re-writing CTRLA.SWRST or CTRLA.ENABLE.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name   | Description                                          |
    /// -----------------------------------------------------------------------
    /// |  1  | ENABLE | Set while CTRLA.ENABLE synchronisation is pending.   |
    /// -----------------------------------------------------------------------
    /// |  0  | SWRST  | Set while CTRLA.SWRST synchronisation is pending.    |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var synchronizationBusyRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(USB_BASE + 0x00) >> 16) & 0x000000FF
        }
    }

    /// SYNCBUSY.SWRST – Software Reset synchronisation in progress.
    @inline(__always)
    static var isSynchronizingReset: Bool {
        (synchronizationBusyRegister & (1 << 0)) != 0
    }

    /// SYNCBUSY.ENABLE – ENABLE synchronisation in progress.
    @inline(__always)
    static var isSynchronizingEnable: Bool {
        (synchronizationBusyRegister & (1 << 1)) != 0
    }


    // MARK: - QOSCTRL – Quality of Service Control (Offset 0x03, 8-bit, common)

    /// QOSCTRL – Quality of Service Control Register
    /// See Section 32.8.3.
    ///
    /// Sets the AHB bus priority for USB command and data transfers. Higher levels
    /// give USB more bus bandwidth, reducing latency at the cost of other peripherals.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// | 3:2  | DQOS | R/W | Data transfer QoS. See QoSLevel.               |
    /// -----------------------------------------------------------------------
    /// | 1:0  | CQOS | R/W | Command transfer QoS. See QoSLevel.            |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var qosControlRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(USB_BASE + 0x00) >> 24) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x00)
            _volatileRegisterWriteUInt32(USB_BASE + 0x00, (word & 0x00FFFFFF) | ((newValue & 0xFF) << 24))
        }
    }

    /// QOSCTRL.CQOS – Command Quality of Service
    @inline(__always)
    static var commandQoS: QoSLevel {
        get {
            let q = qosControlRegister & 0x03
            return QoSLevel(rawValue: q) ?? .sensitive
        }
        set {
            qosControlRegister = (qosControlRegister & ~0x03) | (newValue.rawValue & 0x03)
        }
    }

    /// QOSCTRL.DQOS – Data Quality of Service
    @inline(__always)
    static var dataQoS: QoSLevel {
        get {
            let q = (qosControlRegister >> 2) & 0x03
            return QoSLevel(rawValue: q) ?? .sensitive
        }
        set {
            qosControlRegister = (qosControlRegister & ~(0x03 << 2)) | ((newValue.rawValue & 0x03) << 2)
        }
    }


    // MARK: - FSMSTATUS – Finite State Machine Status (Offset 0x0D, 8-bit, read-only, common)
    //
    // Shared 32-bit word layout at USB_BASE + 0x0C:
    //   [7:0]   = STATUS (device or host, see below)
    //   [15:8]  = FSMSTATUS (common, read-only)
    //   [31:16] = reserved

    /// FSMSTATUS – USB Controller FSM State Register
    /// See Section 32.8.7.
    ///
    /// Reports the current state of the USB controller finite-state machine.
    /// Reading this register is useful for debugging and for determining the current
    /// power/activity state of the bus.
    ///
    /// Common state codes (FSMSTATE field):
    ///   0x01 = ON, 0x02 = SLEEP, 0x03 = SUSPEND,
    ///   0x04 = DNRESUME, 0x05 = UPRESUME, 0x06 = RESET.
    @inline(__always)
    static var fsmStatusRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(USB_BASE + 0x0C) >> 8) & 0x000000FF
        }
    }

    /// FSMSTATUS.FSMSTATE – Controller State (bits [6:0], read-only)
    @inline(__always)
    static var fsmState: UInt32 {
        fsmStatusRegister & 0x7F
    }


    // MARK: - DESCADD – Descriptor Address (Offset 0x24, 32-bit, common)

    /// DESCADD – USB Descriptor Table Base Address Register
    /// See Section 32.8.13.
    ///
    /// The 32-bit address of the SRAM-resident descriptor table. The table must be
    /// aligned to a 16-byte boundary. Each endpoint/pipe occupies two 16-byte bank
    /// descriptor entries (bank 0 at index 2n, bank 1 at index 2n+1).
    ///
    /// Must be written before enabling the USB peripheral.
    @inline(__always)
    static var descriptorAddress: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x24)
        }
        set {
            _volatileRegisterWriteUInt32(USB_BASE + 0x24, newValue)
        }
    }


    // MARK: - PADCAL – Pad Calibration (Offset 0x28, 16-bit, common)
    //
    // Shared 32-bit word at USB_BASE + 0x28; PADCAL occupies bits [15:0].

    /// PADCAL – USB Pad Calibration Register
    /// See Section 32.8.14.
    ///
    /// Analog calibration for the USB D+/D− transceiver pads. Factory values are
    /// automatically loaded from NVM at reset via the device's calibration row.
    /// Do not modify unless explicitly instructed by silicon errata.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name   | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 12:10 | TRIM   | R/W | USB pad trim (3 bits).                       |
    /// -----------------------------------------------------------------------
    /// |  9:5  | TRANSN | R/W | USB data pad pull-down calibration (5 bits). |
    /// -----------------------------------------------------------------------
    /// |  4:0  | TRANSP | R/W | USB data pad pull-up calibration (5 bits).   |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var padCalibrationRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x28) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x28)
            _volatileRegisterWriteUInt32(USB_BASE + 0x28, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// PADCAL.TRANSP – Transceiver Pull-Up Calibration (bits [4:0])
    @inline(__always)
    static var padTransP: UInt32 {
        get { padCalibrationRegister & 0x1F }
        set { padCalibrationRegister = (padCalibrationRegister & ~0x1F) | (newValue & 0x1F) }
    }

    /// PADCAL.TRANSN – Transceiver Pull-Down Calibration (bits [9:5])
    @inline(__always)
    static var padTransN: UInt32 {
        get { (padCalibrationRegister >> 5) & 0x1F }
        set { padCalibrationRegister = (padCalibrationRegister & ~(0x1F << 5)) | ((newValue & 0x1F) << 5) }
    }

    /// PADCAL.TRIM – Pad Trim (bits [12:10])
    @inline(__always)
    static var padTrim: UInt32 {
        get { (padCalibrationRegister >> 10) & 0x07 }
        set { padCalibrationRegister = (padCalibrationRegister & ~(0x07 << 10)) | ((newValue & 0x07) << 10) }
    }


    // MARK: - Device Mode Registers
    //
    // The registers below are at the same offsets as the host-mode registers but have
    // different bit meanings. Enable device mode by setting CTRLA.MODE = 0.


    // MARK: Device CTRLB – Control B (Offset 0x08, 16-bit)
    //
    // Shared 32-bit word layout at USB_BASE + 0x08:
    //   [15:0]  = device CTRLB
    //   [23:16] = DADD (device) / HSOFC (host)
    //   [31:24] = reserved

    /// Device CTRLB – Device Control B Register
    /// See Section 32.8.5 (device).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// | 12:11 | LPMHDSK | R/W | LPM Handshake. See LPMHandshake enum.       |
    /// -----------------------------------------------------------------------
    /// |  10   | GNAK    | R/W | Global NAK — force NAK on all endpoints.    |
    /// -----------------------------------------------------------------------
    /// |   9   | OPMODE2 | R/W | Test Mode J/K/SE0 operation mode (test).    |
    /// -----------------------------------------------------------------------
    /// |   8   | TSTPCKT | R/W | Test Packet Mode.                           |
    /// -----------------------------------------------------------------------
    /// |   7   | TSTK    | R/W | Test K Mode.                                |
    /// -----------------------------------------------------------------------
    /// |   6   | TSTJ    | R/W | Test J Mode.                                |
    /// -----------------------------------------------------------------------
    /// |   4   | NREPLY  | R/W | No Reply — suppress replies in test mode.   |
    /// -----------------------------------------------------------------------
    /// |  3:2  | SPDCONF | R/W | Speed Configuration. See DeviceSpeedConfig. |
    /// -----------------------------------------------------------------------
    /// |   1   | UPRSM   | R/W | Upstream Resume — initiate remote wakeup.   |
    /// -----------------------------------------------------------------------
    /// |   0   | DETACH  | R/W | Detach — disconnect D+ pull-up resistor.    |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var deviceControlBRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x08) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x08)
            _volatileRegisterWriteUInt32(USB_BASE + 0x08, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// Device CTRLB.DETACH – Detach
    ///
    /// When set, the D+ pull-up resistor is disconnected, causing the host to see a disconnect.
    /// Set this before enabling the USB peripheral to control the connect timing.
    @inline(__always)
    static var deviceDetach: Bool {
        get { (deviceControlBRegister & (1 << 0)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 0))
                : (deviceControlBRegister & ~(1 << 0))
        }
    }

    /// Device CTRLB.UPRSM – Upstream Resume
    ///
    /// Set to initiate a remote wakeup sequence. Hardware clears this bit automatically
    /// once the resume signalling is complete.
    @inline(__always)
    static var deviceUpstreamResume: Bool {
        get { (deviceControlBRegister & (1 << 1)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 1))
                : (deviceControlBRegister & ~(1 << 1))
        }
    }

    /// Device CTRLB.SPDCONF – Speed Configuration
    @inline(__always)
    static var deviceSpeedConfig: DeviceSpeedConfig {
        get {
            let s = (deviceControlBRegister >> 2) & 0x03
            return DeviceSpeedConfig(rawValue: s) ?? .fullSpeed
        }
        set {
            deviceControlBRegister = (deviceControlBRegister & ~(0x03 << 2)) | ((newValue.rawValue & 0x03) << 2)
        }
    }

    /// Device CTRLB.NREPLY – No Reply (test mode)
    @inline(__always)
    static var deviceNoReply: Bool {
        get { (deviceControlBRegister & (1 << 4)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 4))
                : (deviceControlBRegister & ~(1 << 4))
        }
    }

    /// Device CTRLB.TSTJ – Test J Mode
    @inline(__always)
    static var deviceTestJ: Bool {
        get { (deviceControlBRegister & (1 << 6)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 6))
                : (deviceControlBRegister & ~(1 << 6))
        }
    }

    /// Device CTRLB.TSTK – Test K Mode
    @inline(__always)
    static var deviceTestK: Bool {
        get { (deviceControlBRegister & (1 << 7)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 7))
                : (deviceControlBRegister & ~(1 << 7))
        }
    }

    /// Device CTRLB.TSTPCKT – Test Packet Mode
    @inline(__always)
    static var deviceTestPacket: Bool {
        get { (deviceControlBRegister & (1 << 8)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 8))
                : (deviceControlBRegister & ~(1 << 8))
        }
    }

    /// Device CTRLB.OPMODE2 – HS Test Mode Opmode
    @inline(__always)
    static var deviceOpMode2: Bool {
        get { (deviceControlBRegister & (1 << 9)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 9))
                : (deviceControlBRegister & ~(1 << 9))
        }
    }

    /// Device CTRLB.GNAK – Global NAK
    ///
    /// When set, all non-control endpoint IN/OUT transactions return NAK.
    /// Useful for atomic operations on the descriptor table.
    @inline(__always)
    static var deviceGlobalNAK: Bool {
        get { (deviceControlBRegister & (1 << 10)) != 0 }
        set {
            deviceControlBRegister = newValue
                ? (deviceControlBRegister | (1 << 10))
                : (deviceControlBRegister & ~(1 << 10))
        }
    }

    /// Device CTRLB.LPMHDSK – LPM Handshake
    @inline(__always)
    static var deviceLPMHandshake: LPMHandshake {
        get {
            let h = (deviceControlBRegister >> 11) & 0x03
            return LPMHandshake(rawValue: h) ?? .noHandshake
        }
        set {
            deviceControlBRegister = (deviceControlBRegister & ~(0x03 << 11)) | ((newValue.rawValue & 0x03) << 11)
        }
    }


    // MARK: DADD – Device Address (Offset 0x0A, 8-bit)

    /// DADD – Device Address Register
    /// See Section 32.8.5 (device).
    ///
    /// The USB device address assigned by the host during enumeration. Write the address
    /// and set ADDEN in the same write after receiving a SET_ADDRESS request.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name  | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// |  7  | ADDEN | R/W | Address Enable — must be set with DADD.         |
    /// -----------------------------------------------------------------------
    /// | 6:0 | DADD  | R/W | Device Address (0–127).                        |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var deviceAddressRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(USB_BASE + 0x08) >> 16) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x08)
            _volatileRegisterWriteUInt32(USB_BASE + 0x08, (word & 0xFF00FFFF) | ((newValue & 0xFF) << 16))
        }
    }

    /// DADD.DADD – Device Address (bits [6:0])
    @inline(__always)
    static var deviceAddress: UInt32 {
        get { deviceAddressRegister & 0x7F }
        set { deviceAddressRegister = (deviceAddressRegister & ~0x7F) | (newValue & 0x7F) }
    }

    /// DADD.ADDEN – Address Enable
    ///
    /// Must be set together with the address in a single write after receiving SET_ADDRESS.
    @inline(__always)
    static var deviceAddressEnable: Bool {
        get { (deviceAddressRegister & (1 << 7)) != 0 }
        set {
            deviceAddressRegister = newValue
                ? (deviceAddressRegister | (1 << 7))
                : (deviceAddressRegister & ~(1 << 7))
        }
    }


    // MARK: Device STATUS – Status (Offset 0x0C, 8-bit, partially read-only)

    /// Device STATUS – Device Status Register
    /// See Section 32.8.7 (device).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name      | R | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 7:6  | LINESTATE | R | Current D+/D− line state. See LineState.     |
    /// -----------------------------------------------------------------------
    /// | 1:0  | SPEED     | R | Speed after reset. See DeviceSpeed.          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var deviceStatusRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x0C) & 0x000000FF
        }
    }

    /// Device STATUS.SPEED – Speed Detected After Bus Reset
    @inline(__always)
    static var deviceSpeed: DeviceSpeed {
        let s = deviceStatusRegister & 0x03
        return DeviceSpeed(rawValue: s) ?? .fullSpeed
    }

    /// Device STATUS.LINESTATE – Current Line State
    @inline(__always)
    static var lineState: LineState {
        let l = (deviceStatusRegister >> 6) & 0x03
        return LineState(rawValue: l) ?? .se0
    }


    // MARK: Device FNUM – Frame Number (Offset 0x10, 16-bit)

    /// Device FNUM – Frame Number Register
    /// See Section 32.8.8 (device).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name  | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  15   | FNCERR| R/W | Frame Number CRC Error. Write '1' to clear.   |
    /// -----------------------------------------------------------------------
    /// | 13:3  | FNUM  |  R  | Current frame number (0–2047).                |
    /// -----------------------------------------------------------------------
    /// |  2:0  | MFNUM |  R  | Micro-frame number (0–7, high-speed only).    |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var deviceFrameNumberRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x10) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x10)
            _volatileRegisterWriteUInt32(USB_BASE + 0x10, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// Device FNUM.MFNUM – Micro-Frame Number (bits [2:0], read-only)
    @inline(__always)
    static var deviceMicroFrameNumber: UInt32 {
        deviceFrameNumberRegister & 0x07
    }

    /// Device FNUM.FNUM – Frame Number (bits [13:3], read-only)
    @inline(__always)
    static var deviceFrameNumber: UInt32 {
        (deviceFrameNumberRegister >> 3) & 0x7FF
    }

    /// Device FNUM.FNCERR – Frame Number CRC Error. Write `true` to clear.
    @inline(__always)
    static var deviceFrameNumberCRCError: Bool {
        get { (deviceFrameNumberRegister & (1 << 15)) != 0 }
        set { if newValue { deviceFrameNumberRegister = (1 << 15) } }
    }


    // MARK: Device Interrupt Registers (INTENCLR 0x14 / INTENSET 0x18 / INTFLAG 0x1C)
    //
    // Each is a standalone 16-bit register in its own 32-bit aligned word.
    // INTENCLR and INTENSET are write-1-to-clear/set; INTFLAG is write-1-to-clear.
    // No read-modify-write needed — zeros have no effect.
    //
    // Device-mode interrupt bit positions:
    //   Bit  2: SUSPEND   – USB bus suspend detected.
    //   Bit  3: SOF       – Start of frame received.
    //   Bit  4: EORST     – End of bus reset.
    //   Bit  5: WAKEUP    – Wakeup detected.
    //   Bit  6: EORSM     – End of resume.
    //   Bit  7: UPRSM     – Upstream resume sent.
    //   Bit  9: RAMACER   – RAM access error.
    //   Bit 10: LPMNYET   – LPM Not Yet handshake sent.
    //   Bit 11: LPMSUSP   – LPM Suspend handshake sent.

    @inline(__always)
    static var deviceInterruptEnableClearRegister: UInt32 {
        get { _volatileRegisterReadUInt32(USB_BASE + 0x14) & 0x0000FFFF }
        set { _volatileRegisterWriteUInt32(USB_BASE + 0x14, newValue & 0xFFFF) }
    }

    @inline(__always)
    static var deviceInterruptEnableSetRegister: UInt32 {
        get { _volatileRegisterReadUInt32(USB_BASE + 0x18) & 0x0000FFFF }
        set { _volatileRegisterWriteUInt32(USB_BASE + 0x18, newValue & 0xFFFF) }
    }

    @inline(__always)
    static var deviceInterruptFlagRegister: UInt32 {
        get { _volatileRegisterReadUInt32(USB_BASE + 0x1C) & 0x0000FFFF }
        set { _volatileRegisterWriteUInt32(USB_BASE + 0x1C, newValue & 0xFFFF) }
    }

    @inline(__always)
    private static func deviceInterruptEnable(bit: UInt32) -> Bool {
        (deviceInterruptEnableClearRegister & (1 << bit)) != 0
    }

    @inline(__always)
    private static func setDeviceInterruptEnable(bit: UInt32, _ enabled: Bool) {
        if enabled { deviceInterruptEnableSetRegister = (1 << bit) }
        else        { deviceInterruptEnableClearRegister = (1 << bit) }
    }

    /// Device SUSPEND – Bus suspend interrupt enable.
    @inline(__always)
    static var deviceSuspendInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 2) }
        set { setDeviceInterruptEnable(bit: 2, newValue) }
    }

    /// Device SOF – Start-of-frame interrupt enable.
    @inline(__always)
    static var deviceSOFInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 3) }
        set { setDeviceInterruptEnable(bit: 3, newValue) }
    }

    /// Device EORST – End-of-reset interrupt enable.
    @inline(__always)
    static var deviceEndOfResetInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 4) }
        set { setDeviceInterruptEnable(bit: 4, newValue) }
    }

    /// Device WAKEUP – Wakeup interrupt enable.
    @inline(__always)
    static var deviceWakeupInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 5) }
        set { setDeviceInterruptEnable(bit: 5, newValue) }
    }

    /// Device EORSM – End-of-resume interrupt enable.
    @inline(__always)
    static var deviceEndOfResumeInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 6) }
        set { setDeviceInterruptEnable(bit: 6, newValue) }
    }

    /// Device UPRSM – Upstream resume sent interrupt enable.
    @inline(__always)
    static var deviceUpstreamResumeInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 7) }
        set { setDeviceInterruptEnable(bit: 7, newValue) }
    }

    /// Device RAMACER – RAM access error interrupt enable.
    @inline(__always)
    static var deviceRAMAccessErrorInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 9) }
        set { setDeviceInterruptEnable(bit: 9, newValue) }
    }

    /// Device LPMNYET – LPM Not Yet interrupt enable.
    @inline(__always)
    static var deviceLPMNotYetInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 10) }
        set { setDeviceInterruptEnable(bit: 10, newValue) }
    }

    /// Device LPMSUSP – LPM Suspend interrupt enable.
    @inline(__always)
    static var deviceLPMSuspendInterruptEnable: Bool {
        get { deviceInterruptEnable(bit: 11) }
        set { setDeviceInterruptEnable(bit: 11, newValue) }
    }

    // Device INTFLAG status and clear properties. Write `true` to clear a flag.

    /// Device SUSPEND flag. Write `true` to clear.
    @inline(__always)
    static var deviceSuspended: Bool {
        get { (deviceInterruptFlagRegister & (1 << 2)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 2) } }
    }

    /// Device SOF flag. Write `true` to clear.
    @inline(__always)
    static var deviceStartOfFrame: Bool {
        get { (deviceInterruptFlagRegister & (1 << 3)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 3) } }
    }

    /// Device EORST – End of bus reset flag. Write `true` to clear.
    @inline(__always)
    static var deviceEndOfReset: Bool {
        get { (deviceInterruptFlagRegister & (1 << 4)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 4) } }
    }

    /// Device WAKEUP flag. Write `true` to clear.
    @inline(__always)
    static var deviceWakeup: Bool {
        get { (deviceInterruptFlagRegister & (1 << 5)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 5) } }
    }

    /// Device EORSM – End of resume flag. Write `true` to clear.
    @inline(__always)
    static var deviceEndOfResume: Bool {
        get { (deviceInterruptFlagRegister & (1 << 6)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 6) } }
    }

    /// Device UPRSM – Upstream resume sent flag. Write `true` to clear.
    @inline(__always)
    static var deviceUpstreamResumeSent: Bool {
        get { (deviceInterruptFlagRegister & (1 << 7)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 7) } }
    }

    /// Device RAMACER – RAM access error flag. Write `true` to clear.
    @inline(__always)
    static var deviceRAMAccessError: Bool {
        get { (deviceInterruptFlagRegister & (1 << 9)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 9) } }
    }

    /// Device LPMNYET – LPM Not Yet flag. Write `true` to clear.
    @inline(__always)
    static var deviceLPMNotYet: Bool {
        get { (deviceInterruptFlagRegister & (1 << 10)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 10) } }
    }

    /// Device LPMSUSP – LPM Suspend flag. Write `true` to clear.
    @inline(__always)
    static var deviceLPMSuspend: Bool {
        get { (deviceInterruptFlagRegister & (1 << 11)) != 0 }
        set { if newValue { deviceInterruptFlagRegister = (1 << 11) } }
    }


    // MARK: EPINTSMRY – Endpoint Interrupt Summary (Offset 0x20, 16-bit, device, read-only)

    /// EPINTSMRY – Endpoint Interrupt Summary Register
    /// See Section 32.8.12 (device).
    ///
    /// Each bit corresponds to one endpoint. A bit is set while any pending interrupt
    /// flag exists in the corresponding endpoint's EPINTFLAG register.
    /// Use this register to quickly identify which endpoint caused an interrupt without
    /// reading all eight EPINTFLAG registers.
    @inline(__always)
    static var endpointInterruptSummaryRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x20) & 0x0000FFFF
        }
    }

    /// Returns `true` if endpoint `ep` (0–7) has a pending interrupt flag.
    @inline(__always)
    static func endpointHasPendingInterrupt(ep: UInt) -> Bool {
        (endpointInterruptSummaryRegister & (1 << ep)) != 0
    }


    // MARK: - Host Mode Registers
    //
    // These registers occupy the same offsets as device-mode registers but with
    // different bit definitions. Enable host mode via CTRLA.MODE = 1.


    // MARK: Host CTRLB – Control B (Offset 0x08, 16-bit)

    /// Host CTRLB – Host Control B Register
    /// See Section 32.8.5 (host).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit  | Name      | R/W | Description                               |
    /// -----------------------------------------------------------------------
    /// |  11  | L1RESUME  | R/W | LPM L1 Resume.                            |
    /// -----------------------------------------------------------------------
    /// |  10  | VBUSOK    | R/W | VBUS OK — indicates VBUS is present.       |
    /// -----------------------------------------------------------------------
    /// |   9  | BUSRESET  | R/W | Start bus reset signalling.                |
    /// -----------------------------------------------------------------------
    /// |   8  | SOFE      | R/W | SOF Enable — enables host SOF generation.  |
    /// -----------------------------------------------------------------------
    /// |   7  | TSTK      | R/W | Test K Mode.                               |
    /// -----------------------------------------------------------------------
    /// |   6  | TSTJ      | R/W | Test J Mode.                               |
    /// -----------------------------------------------------------------------
    /// |   4  | AUTORESUME| R/W | Auto-Resume — hardware resumes on wakeup.  |
    /// -----------------------------------------------------------------------
    /// |  3:2 | SPDCONF   | R/W | Speed Configuration. See HostSpeedConfig.  |
    /// -----------------------------------------------------------------------
    /// |   1  | RESUME    | R/W | Send resume signalling to device.          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var hostControlBRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x08) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x08)
            _volatileRegisterWriteUInt32(USB_BASE + 0x08, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// Host CTRLB.RESUME – Resume Signalling
    @inline(__always)
    static var hostResume: Bool {
        get { (hostControlBRegister & (1 << 1)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 1))
                : (hostControlBRegister & ~(1 << 1))
        }
    }

    /// Host CTRLB.SPDCONF – Speed Configuration
    @inline(__always)
    static var hostSpeedConfig: HostSpeedConfig {
        get {
            let s = (hostControlBRegister >> 2) & 0x03
            return HostSpeedConfig(rawValue: s) ?? .normal
        }
        set {
            hostControlBRegister = (hostControlBRegister & ~(0x03 << 2)) | ((newValue.rawValue & 0x03) << 2)
        }
    }

    /// Host CTRLB.AUTORESUME – Automatic Resume
    @inline(__always)
    static var hostAutoResume: Bool {
        get { (hostControlBRegister & (1 << 4)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 4))
                : (hostControlBRegister & ~(1 << 4))
        }
    }

    /// Host CTRLB.TSTJ – Test J Mode
    @inline(__always)
    static var hostTestJ: Bool {
        get { (hostControlBRegister & (1 << 6)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 6))
                : (hostControlBRegister & ~(1 << 6))
        }
    }

    /// Host CTRLB.TSTK – Test K Mode
    @inline(__always)
    static var hostTestK: Bool {
        get { (hostControlBRegister & (1 << 7)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 7))
                : (hostControlBRegister & ~(1 << 7))
        }
    }

    /// Host CTRLB.SOFE – SOF Enable
    ///
    /// When set, the host generates SOF tokens at the appropriate rate.
    /// Must be set after a bus reset before beginning transfers.
    @inline(__always)
    static var hostSOFEnable: Bool {
        get { (hostControlBRegister & (1 << 8)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 8))
                : (hostControlBRegister & ~(1 << 8))
        }
    }

    /// Host CTRLB.BUSRESET – Bus Reset
    ///
    /// Set to start bus reset signalling. Hardware clears this bit automatically
    /// after the reset period is complete.
    @inline(__always)
    static var hostBusReset: Bool {
        get { (hostControlBRegister & (1 << 9)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 9))
                : (hostControlBRegister & ~(1 << 9))
        }
    }

    /// Host CTRLB.VBUSOK – VBUS OK
    ///
    /// Write '1' when VBUS power is valid. Required before the host can connect.
    @inline(__always)
    static var hostVBUSOK: Bool {
        get { (hostControlBRegister & (1 << 10)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 10))
                : (hostControlBRegister & ~(1 << 10))
        }
    }

    /// Host CTRLB.L1RESUME – LPM L1 Resume
    @inline(__always)
    static var hostL1Resume: Bool {
        get { (hostControlBRegister & (1 << 11)) != 0 }
        set {
            hostControlBRegister = newValue
                ? (hostControlBRegister | (1 << 11))
                : (hostControlBRegister & ~(1 << 11))
        }
    }


    // MARK: HSOFC – Host Start-Of-Frame Control (Offset 0x0A, 8-bit)

    /// HSOFC – Host Start-Of-Frame Control Register
    /// See Section 32.8.5 (host).
    ///
    /// Controls the SOF frame length correction used to maintain synchronization
    /// with the connected device's bit-stuffing clock.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name  | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// |  4  | FLENCE| R/W | Frame Length Control Enable.                    |
    /// -----------------------------------------------------------------------
    /// | 3:0 | FLENC | R/W | Frame Length Correction value (4 bits).         |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var hostSOFControlRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(USB_BASE + 0x08) >> 16) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(USB_BASE + 0x08)
            _volatileRegisterWriteUInt32(USB_BASE + 0x08, (word & 0xFF00FFFF) | ((newValue & 0xFF) << 16))
        }
    }

    /// HSOFC.FLENC – Frame Length Correction value (bits [3:0])
    @inline(__always)
    static var hostFrameLengthCorrection: UInt32 {
        get { hostSOFControlRegister & 0x0F }
        set { hostSOFControlRegister = (hostSOFControlRegister & ~0x0F) | (newValue & 0x0F) }
    }

    /// HSOFC.FLENCE – Frame Length Correction Enable
    @inline(__always)
    static var hostFrameLengthCorrectionEnable: Bool {
        get { (hostSOFControlRegister & (1 << 4)) != 0 }
        set {
            hostSOFControlRegister = newValue
                ? (hostSOFControlRegister | (1 << 4))
                : (hostSOFControlRegister & ~(1 << 4))
        }
    }


    // MARK: Host STATUS – Status (Offset 0x0C, 8-bit, read-only)

    /// Host STATUS – Host Status Register
    /// See Section 32.8.7 (host).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name  | R | Description                                      |
    /// -----------------------------------------------------------------------
    /// | 2:0  | SPEED | R | Connected device speed: 0=FS, 1=HS(N/A), 2=LS. |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var hostStatusRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x0C) & 0x000000FF
        }
    }

    /// Host STATUS.SPEED – Connected Device Speed (read-only)
    ///
    /// Valid after a bus reset has completed. 0 = Full-Speed, 2 = Low-Speed.
    @inline(__always)
    static var hostConnectedDeviceSpeed: UInt32 {
        hostStatusRegister & 0x07
    }


    // MARK: Host FNUM – Frame Number (Offset 0x10, 16-bit)

    /// Host FNUM – Host Frame Number Register
    /// See Section 32.8.8 (host).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name  | R | Description                                     |
    /// -----------------------------------------------------------------------
    /// | 13:3  | FNUM  | R | Current frame number (0–2047).                  |
    /// -----------------------------------------------------------------------
    /// |  2:0  | MFNUM | R | Micro-frame number (0–7).                       |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var hostFrameNumberRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x10) & 0x0000FFFF
        }
    }

    /// Host FNUM.MFNUM – Micro-Frame Number (bits [2:0])
    @inline(__always)
    static var hostMicroFrameNumber: UInt32 {
        hostFrameNumberRegister & 0x07
    }

    /// Host FNUM.FNUM – Frame Number (bits [13:3])
    @inline(__always)
    static var hostFrameNumber: UInt32 {
        (hostFrameNumberRegister >> 3) & 0x7FF
    }


    // MARK: FLENHIGH – Frame Length High Byte (Offset 0x12, 8-bit, host, read-only)

    /// FLENHIGH – Host Frame Length High Byte Register
    /// See Section 32.8.9 (host).
    ///
    /// Upper byte of the current SOF frame length counter. Used with FNUM to monitor
    /// SOF timing accuracy.
    @inline(__always)
    static var hostFrameLengthHighByte: UInt32 {
        get {
            (_volatileRegisterReadUInt32(USB_BASE + 0x10) >> 16) & 0x000000FF
        }
    }


    // MARK: Host Interrupt Registers (INTENCLR 0x14 / INTENSET 0x18 / INTFLAG 0x1C)
    //
    // Host-mode interrupt bit positions:
    //   Bit  0: HSOF     – Host start of frame.
    //   Bit  2: RST      – Bus reset detected.
    //   Bit  3: WAKEUP   – Wakeup detected.
    //   Bit  4: DNRSM    – Downstream resume detected.
    //   Bit  5: UPRSM    – Upstream resume detected.
    //   Bit  6: RAMACER  – RAM access error.
    //   Bit  7: DCONN    – Device connection detected.
    //   Bit  8: DDISC    – Device disconnection detected.

    @inline(__always)
    static var hostInterruptEnableClearRegister: UInt32 {
        get { _volatileRegisterReadUInt32(USB_BASE + 0x14) & 0x0000FFFF }
        set { _volatileRegisterWriteUInt32(USB_BASE + 0x14, newValue & 0xFFFF) }
    }

    @inline(__always)
    static var hostInterruptEnableSetRegister: UInt32 {
        get { _volatileRegisterReadUInt32(USB_BASE + 0x18) & 0x0000FFFF }
        set { _volatileRegisterWriteUInt32(USB_BASE + 0x18, newValue & 0xFFFF) }
    }

    @inline(__always)
    static var hostInterruptFlagRegister: UInt32 {
        get { _volatileRegisterReadUInt32(USB_BASE + 0x1C) & 0x0000FFFF }
        set { _volatileRegisterWriteUInt32(USB_BASE + 0x1C, newValue & 0xFFFF) }
    }

    @inline(__always)
    private static func hostInterruptEnable(bit: UInt32) -> Bool {
        (hostInterruptEnableClearRegister & (1 << bit)) != 0
    }

    @inline(__always)
    private static func setHostInterruptEnable(bit: UInt32, _ enabled: Bool) {
        if enabled { hostInterruptEnableSetRegister = (1 << bit) }
        else        { hostInterruptEnableClearRegister = (1 << bit) }
    }

    /// Host HSOF – Host SOF interrupt enable.
    @inline(__always)
    static var hostSOFInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 0) }
        set { setHostInterruptEnable(bit: 0, newValue) }
    }

    /// Host RST – Bus reset interrupt enable.
    @inline(__always)
    static var hostBusResetInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 2) }
        set { setHostInterruptEnable(bit: 2, newValue) }
    }

    /// Host WAKEUP – Wakeup interrupt enable.
    @inline(__always)
    static var hostWakeupInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 3) }
        set { setHostInterruptEnable(bit: 3, newValue) }
    }

    /// Host DNRSM – Downstream resume interrupt enable.
    @inline(__always)
    static var hostDownstreamResumeInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 4) }
        set { setHostInterruptEnable(bit: 4, newValue) }
    }

    /// Host UPRSM – Upstream resume interrupt enable.
    @inline(__always)
    static var hostUpstreamResumeInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 5) }
        set { setHostInterruptEnable(bit: 5, newValue) }
    }

    /// Host RAMACER – RAM access error interrupt enable.
    @inline(__always)
    static var hostRAMAccessErrorInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 6) }
        set { setHostInterruptEnable(bit: 6, newValue) }
    }

    /// Host DCONN – Device connection interrupt enable.
    @inline(__always)
    static var hostDeviceConnectionInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 7) }
        set { setHostInterruptEnable(bit: 7, newValue) }
    }

    /// Host DDISC – Device disconnection interrupt enable.
    @inline(__always)
    static var hostDeviceDisconnectInterruptEnable: Bool {
        get { hostInterruptEnable(bit: 8) }
        set { setHostInterruptEnable(bit: 8, newValue) }
    }

    // Host INTFLAG status and clear properties. Write `true` to clear.

    /// Host HSOF flag. Write `true` to clear.
    @inline(__always)
    static var hostSOF: Bool {
        get { (hostInterruptFlagRegister & (1 << 0)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 0) } }
    }

    /// Host RST – Bus reset detected flag. Write `true` to clear.
    @inline(__always)
    static var hostBusResetDetected: Bool {
        get { (hostInterruptFlagRegister & (1 << 2)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 2) } }
    }

    /// Host WAKEUP flag. Write `true` to clear.
    @inline(__always)
    static var hostWakeup: Bool {
        get { (hostInterruptFlagRegister & (1 << 3)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 3) } }
    }

    /// Host DNRSM – Downstream resume flag. Write `true` to clear.
    @inline(__always)
    static var hostDownstreamResume: Bool {
        get { (hostInterruptFlagRegister & (1 << 4)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 4) } }
    }

    /// Host UPRSM – Upstream resume flag. Write `true` to clear.
    @inline(__always)
    static var hostUpstreamResume: Bool {
        get { (hostInterruptFlagRegister & (1 << 5)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 5) } }
    }

    /// Host RAMACER – RAM access error flag. Write `true` to clear.
    @inline(__always)
    static var hostRAMAccessError: Bool {
        get { (hostInterruptFlagRegister & (1 << 6)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 6) } }
    }

    /// Host DCONN – Device connected flag. Write `true` to clear.
    @inline(__always)
    static var hostDeviceConnected: Bool {
        get { (hostInterruptFlagRegister & (1 << 7)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 7) } }
    }

    /// Host DDISC – Device disconnected flag. Write `true` to clear.
    @inline(__always)
    static var hostDeviceDisconnected: Bool {
        get { (hostInterruptFlagRegister & (1 << 8)) != 0 }
        set { if newValue { hostInterruptFlagRegister = (1 << 8) } }
    }


    // MARK: PINTSMRY – Pipe Interrupt Summary (Offset 0x20, 16-bit, host, read-only)

    /// PINTSMRY – Pipe Interrupt Summary Register
    /// See Section 32.8.12 (host).
    ///
    /// Each bit corresponds to one pipe (0–7). A bit is set while any pending interrupt
    /// flag exists in the corresponding pipe's PINTFLAG register.
    @inline(__always)
    static var pipeInterruptSummaryRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(USB_BASE + 0x20) & 0x0000FFFF
        }
    }

    /// Returns `true` if pipe `pipe` (0–7) has a pending interrupt flag.
    @inline(__always)
    static func pipeHasPendingInterrupt(pipe: UInt) -> Bool {
        (pipeInterruptSummaryRegister & (1 << pipe)) != 0
    }


    // MARK: - Device Endpoint Registers (ep 0–7)
    //
    // For each endpoint n (0–7) the register block begins at USB_EP_BASE + n * 0x20.
    //
    // 32-bit word layout:
    //
    //   base + 0x00  [7:0]   EPCFG    – Endpoint Configuration (R/W)
    //                [31:24] reserved  (BINTERVAL in host mode at same offset)
    //
    //   base + 0x04  [7:0]   EPSTATUSCLR – write-1-to-clear status bits
    //                [15:8]  EPSTATUSSET – write-1-to-set status bits
    //                [23:16] EPSTATUS    – current status (read-only)
    //                [31:24] EPINTFLAG   – interrupt flags (write-1-to-clear)
    //
    //   base + 0x08  [7:0]   EPINTENCLR – write-1-to-clear interrupt enable
    //                [15:8]  EPINTENSET – write-1-to-set interrupt enable
    //
    // Writing 0 to any set/clear/flag register has no effect — no RMW needed.

    // MARK: Device endpoint private helpers

    @inline(__always)
    private static func epConfigWord(_ ep: UInt) -> UInt32 {
        _volatileRegisterReadUInt32(USB_EP_BASE + ep &* 0x20)
    }

    @inline(__always)
    private static func epStatusWord(_ ep: UInt) -> UInt32 {
        _volatileRegisterReadUInt32(USB_EP_BASE + ep &* 0x20 + 0x04)
    }

    @inline(__always)
    private static func epInterruptWord(_ ep: UInt) -> UInt32 {
        _volatileRegisterReadUInt32(USB_EP_BASE + ep &* 0x20 + 0x08)
    }

    /// Writes to EPCFG (bits [7:0]) while preserving upper bytes of the config word.
    @inline(__always)
    private static func writeEPConfig(_ ep: UInt, _ value: UInt32) {
        let word = _volatileRegisterReadUInt32(USB_EP_BASE + ep &* 0x20)
        _volatileRegisterWriteUInt32(USB_EP_BASE + ep &* 0x20, (word & 0xFFFFFF00) | (value & 0xFF))
    }

    /// Writes to EPSTATUSCLR (bits [7:0] of status word). No RMW needed.
    @inline(__always)
    private static func clearEPStatus(_ ep: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + ep &* 0x20 + 0x04, bits & 0xFF)
    }

    /// Writes to EPSTATUSSET (bits [15:8] of status word). No RMW needed.
    @inline(__always)
    private static func setEPStatus(_ ep: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + ep &* 0x20 + 0x04, (bits & 0xFF) << 8)
    }

    /// Writes to EPINTFLAG (bits [31:24] of status word) to clear flags. No RMW needed.
    @inline(__always)
    private static func clearEPIntFlag(_ ep: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + ep &* 0x20 + 0x04, (bits & 0xFF) << 24)
    }

    /// Writes to EPINTENCLR (bits [7:0] of interrupt word). No RMW needed.
    @inline(__always)
    private static func clearEPIntEnable(_ ep: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + ep &* 0x20 + 0x08, bits & 0xFF)
    }

    /// Writes to EPINTENSET (bits [15:8] of interrupt word). No RMW needed.
    @inline(__always)
    private static func setEPIntEnable(_ ep: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + ep &* 0x20 + 0x08, (bits & 0xFF) << 8)
    }

    // MARK: EPCFG – Endpoint Configuration

    /// EPCFG – Endpoint `ep` Configuration Register
    /// See Section 32.8.15.
    ///
    /// Returns the raw 8-bit EPCFG value for the given endpoint.
    /// Use `endpointBankType(ep:bank:)` and `setEndpointBankType(ep:bank:type:)` for
    /// individual field access.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name    | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 6:4  | EPTYPE1 | R/W | Bank 1 (IN direction) type. See enum.        |
    /// -----------------------------------------------------------------------
    /// |  3   | NYETDIS | R/W | NYET Disable (control endpoints).            |
    /// -----------------------------------------------------------------------
    /// | 2:0  | EPTYPE0 | R/W | Bank 0 (OUT direction) type. See enum.       |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static func endpointConfigRegister(ep: UInt) -> UInt32 {
        epConfigWord(ep) & 0xFF
    }

    /// Returns the bank type for bank `bank` (0 = OUT, 1 = IN) of endpoint `ep`.
    @inline(__always)
    static func endpointBankType(ep: UInt, bank: UInt) -> EndpointBankType {
        let shift = bank == 0 ? UInt32(0) : UInt32(4)
        let raw = (endpointConfigRegister(ep: ep) >> shift) & 0x07
        return EndpointBankType(rawValue: raw) ?? .disabled
    }

    /// Sets the bank type for bank `bank` (0 = OUT, 1 = IN) of endpoint `ep`.
    @inline(__always)
    static func setEndpointBankType(ep: UInt, bank: UInt, type bankType: EndpointBankType) {
        let shift = bank == 0 ? UInt32(0) : UInt32(4)
        let mask  = UInt32(0x07) << shift
        let cfg   = endpointConfigRegister(ep: ep)
        writeEPConfig(ep, (cfg & ~mask) | ((bankType.rawValue & 0x07) << shift))
    }

    /// EPCFG.NYETDIS – NYET Disable for endpoint `ep` (bit 3).
    ///
    /// When set, the endpoint never issues NYET handshakes (used for control endpoints).
    @inline(__always)
    static func endpointNYETDisable(ep: UInt) -> Bool {
        (endpointConfigRegister(ep: ep) & (1 << 3)) != 0
    }

    @inline(__always)
    static func setEndpointNYETDisable(ep: UInt, _ disabled: Bool) {
        let cfg = endpointConfigRegister(ep: ep)
        writeEPConfig(ep, disabled ? (cfg | (1 << 3)) : (cfg & ~(1 << 3)))
    }

    // MARK: EPSTATUS – Endpoint Status

    /// Returns the raw EPSTATUS byte for endpoint `ep` (bits [23:16] of status word).
    ///
    /// EPSTATUS bit positions:
    ///   Bit 7: BK1RDY   – Bank 1 ready (data available for IN transfer).
    ///   Bit 6: BK0RDY   – Bank 0 ready (data available; host may read OUT).
    ///   Bit 5: STALLRQ1 – Stall request on bank 1.
    ///   Bit 4: STALLRQ0 – Stall request on bank 0.
    ///   Bit 2: CURBK    – Current bank (0 or 1).
    ///   Bit 1: DTGLIN   – Data toggle for IN bank.
    ///   Bit 0: DTGLOUT  – Data toggle for OUT bank.
    @inline(__always)
    static func endpointStatus(ep: UInt) -> UInt32 {
        (epStatusWord(ep) >> 16) & 0xFF
    }

    /// EPSTATUS.DTGLOUT – Data toggle OUT bank for endpoint `ep`.
    @inline(__always)
    static func endpointDataToggleOut(ep: UInt) -> Bool {
        (endpointStatus(ep: ep) & (1 << 0)) != 0
    }

    @inline(__always)
    static func setEndpointDataToggleOut(ep: UInt, _ value: Bool) {
        if value { setEPStatus(ep, bits: 1 << 0) }
        else      { clearEPStatus(ep, bits: 1 << 0) }
    }

    /// EPSTATUS.DTGLIN – Data toggle IN bank for endpoint `ep`.
    @inline(__always)
    static func endpointDataToggleIn(ep: UInt) -> Bool {
        (endpointStatus(ep: ep) & (1 << 1)) != 0
    }

    @inline(__always)
    static func setEndpointDataToggleIn(ep: UInt, _ value: Bool) {
        if value { setEPStatus(ep, bits: 1 << 1) }
        else      { clearEPStatus(ep, bits: 1 << 1) }
    }

    /// EPSTATUS.CURBK – Current bank for endpoint `ep` (read-only; set by hardware in dual-bank mode).
    @inline(__always)
    static func endpointCurrentBank(ep: UInt) -> UInt {
        (endpointStatus(ep: ep) & (1 << 2)) != 0 ? 1 : 0
    }

    /// EPSTATUS.STALLRQ0 – Stall request on bank 0 (OUT) of endpoint `ep`.
    @inline(__always)
    static func endpointStallRequestBank0(ep: UInt) -> Bool {
        (endpointStatus(ep: ep) & (1 << 4)) != 0
    }

    @inline(__always)
    static func setEndpointStallRequestBank0(ep: UInt, _ value: Bool) {
        if value { setEPStatus(ep, bits: 1 << 4) }
        else      { clearEPStatus(ep, bits: 1 << 4) }
    }

    /// EPSTATUS.STALLRQ1 – Stall request on bank 1 (IN) of endpoint `ep`.
    @inline(__always)
    static func endpointStallRequestBank1(ep: UInt) -> Bool {
        (endpointStatus(ep: ep) & (1 << 5)) != 0
    }

    @inline(__always)
    static func setEndpointStallRequestBank1(ep: UInt, _ value: Bool) {
        if value { setEPStatus(ep, bits: 1 << 5) }
        else      { clearEPStatus(ep, bits: 1 << 5) }
    }

    /// EPSTATUS.BK0RDY – Bank 0 ready for endpoint `ep`.
    ///
    /// In OUT mode: set by hardware after a packet is received; clear to re-arm the bank.
    /// In dual-bank IN mode: set by firmware to indicate buffer is filled and ready to send.
    @inline(__always)
    static func endpointBank0Ready(ep: UInt) -> Bool {
        (endpointStatus(ep: ep) & (1 << 6)) != 0
    }

    @inline(__always)
    static func setEndpointBank0Ready(ep: UInt, _ value: Bool) {
        if value { setEPStatus(ep, bits: 1 << 6) }
        else      { clearEPStatus(ep, bits: 1 << 6) }
    }

    /// EPSTATUS.BK1RDY – Bank 1 ready for endpoint `ep`.
    ///
    /// In IN mode: set by firmware to indicate the IN buffer is filled; cleared by hardware after send.
    @inline(__always)
    static func endpointBank1Ready(ep: UInt) -> Bool {
        (endpointStatus(ep: ep) & (1 << 7)) != 0
    }

    @inline(__always)
    static func setEndpointBank1Ready(ep: UInt, _ value: Bool) {
        if value { setEPStatus(ep, bits: 1 << 7) }
        else      { clearEPStatus(ep, bits: 1 << 7) }
    }

    // MARK: EPINTFLAG – Endpoint Interrupt Flag

    /// Returns the raw EPINTFLAG byte for endpoint `ep` (bits [31:24] of status word).
    ///
    /// EPINTFLAG bit positions:
    ///   Bit 6: STALL1  – STALL sent on bank 1.
    ///   Bit 5: STALL0  – STALL sent on bank 0.
    ///   Bit 4: RXSTP   – SETUP packet received.
    ///   Bit 3: TRFAIL1 – Transfer failed on bank 1.
    ///   Bit 2: TRFAIL0 – Transfer failed on bank 0.
    ///   Bit 1: TRCPT1  – Transfer complete on bank 1.
    ///   Bit 0: TRCPT0  – Transfer complete on bank 0.
    @inline(__always)
    static func endpointInterruptFlags(ep: UInt) -> UInt32 {
        (epStatusWord(ep) >> 24) & 0xFF
    }

    /// EPINTFLAG.TRCPT0 – Transfer complete bank 0. Write `true` to clear.
    @inline(__always)
    static func endpointTransferCompleteBank0(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 0)) != 0
    }

    @inline(__always)
    static func clearEndpointTransferCompleteBank0(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 0)
    }

    /// EPINTFLAG.TRCPT1 – Transfer complete bank 1. Write `true` to clear.
    @inline(__always)
    static func endpointTransferCompleteBank1(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 1)) != 0
    }

    @inline(__always)
    static func clearEndpointTransferCompleteBank1(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 1)
    }

    /// EPINTFLAG.TRFAIL0 – Transfer failed bank 0. Write `true` to clear.
    @inline(__always)
    static func endpointTransferFailedBank0(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 2)) != 0
    }

    @inline(__always)
    static func clearEndpointTransferFailedBank0(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 2)
    }

    /// EPINTFLAG.TRFAIL1 – Transfer failed bank 1. Write `true` to clear.
    @inline(__always)
    static func endpointTransferFailedBank1(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 3)) != 0
    }

    @inline(__always)
    static func clearEndpointTransferFailedBank1(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 3)
    }

    /// EPINTFLAG.RXSTP – SETUP packet received. Write `true` to clear.
    @inline(__always)
    static func endpointSetupReceived(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 4)) != 0
    }

    @inline(__always)
    static func clearEndpointSetupReceived(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 4)
    }

    /// EPINTFLAG.STALL0 – STALL sent on bank 0. Write `true` to clear.
    @inline(__always)
    static func endpointStallSentBank0(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 5)) != 0
    }

    @inline(__always)
    static func clearEndpointStallSentBank0(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 5)
    }

    /// EPINTFLAG.STALL1 – STALL sent on bank 1. Write `true` to clear.
    @inline(__always)
    static func endpointStallSentBank1(ep: UInt) -> Bool {
        (endpointInterruptFlags(ep: ep) & (1 << 6)) != 0
    }

    @inline(__always)
    static func clearEndpointStallSentBank1(ep: UInt) {
        clearEPIntFlag(ep, bits: 1 << 6)
    }

    // MARK: EPINTEN – Endpoint Interrupt Enable

    /// Returns the raw EPINTENCLR byte for endpoint `ep` (bits [7:0] of interrupt word).
    ///
    /// Bit layout mirrors EPINTFLAG: TRCPT0[0], TRCPT1[1], TRFAIL0[2], TRFAIL1[3],
    /// RXSTP[4], STALL0[5], STALL1[6].
    @inline(__always)
    static func endpointInterruptEnable(ep: UInt) -> UInt32 {
        epInterruptWord(ep) & 0xFF
    }

    @inline(__always)
    private static func epIntEnabled(ep: UInt, bit: UInt32) -> Bool {
        (endpointInterruptEnable(ep: ep) & (1 << bit)) != 0
    }

    @inline(__always)
    private static func setEPIntEnabled(ep: UInt, bit: UInt32, _ enabled: Bool) {
        if enabled { setEPIntEnable(ep, bits: 1 << bit) }
        else        { clearEPIntEnable(ep, bits: 1 << bit) }
    }

    /// EPINTEN.TRCPT0 – Transfer complete bank 0 interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointTransferCompleteBank0InterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 0)
    }

    @inline(__always)
    static func setEndpointTransferCompleteBank0InterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 0, enabled)
    }

    /// EPINTEN.TRCPT1 – Transfer complete bank 1 interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointTransferCompleteBank1InterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 1)
    }

    @inline(__always)
    static func setEndpointTransferCompleteBank1InterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 1, enabled)
    }

    /// EPINTEN.TRFAIL0 – Transfer failed bank 0 interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointTransferFailedBank0InterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 2)
    }

    @inline(__always)
    static func setEndpointTransferFailedBank0InterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 2, enabled)
    }

    /// EPINTEN.TRFAIL1 – Transfer failed bank 1 interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointTransferFailedBank1InterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 3)
    }

    @inline(__always)
    static func setEndpointTransferFailedBank1InterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 3, enabled)
    }

    /// EPINTEN.RXSTP – SETUP received interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointSetupReceivedInterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 4)
    }

    @inline(__always)
    static func setEndpointSetupReceivedInterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 4, enabled)
    }

    /// EPINTEN.STALL0 – STALL sent bank 0 interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointStallSentBank0InterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 5)
    }

    @inline(__always)
    static func setEndpointStallSentBank0InterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 5, enabled)
    }

    /// EPINTEN.STALL1 – STALL sent bank 1 interrupt enable for endpoint `ep`.
    @inline(__always)
    static func endpointStallSentBank1InterruptEnable(ep: UInt) -> Bool {
        epIntEnabled(ep: ep, bit: 6)
    }

    @inline(__always)
    static func setEndpointStallSentBank1InterruptEnable(ep: UInt, _ enabled: Bool) {
        setEPIntEnabled(ep: ep, bit: 6, enabled)
    }


    // MARK: - Host Pipe Registers (pipe 0–7)
    //
    // Host pipe registers share the same base address (USB_EP_BASE) and stride (0x20)
    // as device endpoint registers but have different register names and bit definitions.
    //
    // 32-bit word layout:
    //
    //   base + 0x00  [7:0]   PCFG      – Pipe Configuration (R/W)
    //                [23:16] reserved
    //                [31:24] BINTERVAL – Polling interval in frames (R/W)
    //
    //   base + 0x04  [7:0]   PSTATUSCLR – write-1-to-clear status
    //                [15:8]  PSTATUSSET – write-1-to-set status
    //                [23:16] PSTATUS    – current pipe status (read-only)
    //                [31:24] PINTFLAG   – interrupt flags (write-1-to-clear)
    //
    //   base + 0x08  [7:0]   PINTENCLR – write-1-to-clear interrupt enable
    //                [15:8]  PINTENSET – write-1-to-set interrupt enable

    // MARK: Host pipe private helpers (reuse ep helpers — same physical registers)

    @inline(__always)
    private static func clearPipeStatus(_ pipe: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20 + 0x04, bits & 0xFF)
    }

    @inline(__always)
    private static func setPipeStatus(_ pipe: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20 + 0x04, (bits & 0xFF) << 8)
    }

    @inline(__always)
    private static func clearPipeIntFlag(_ pipe: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20 + 0x04, (bits & 0xFF) << 24)
    }

    @inline(__always)
    private static func clearPipeIntEnable(_ pipe: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20 + 0x08, bits & 0xFF)
    }

    @inline(__always)
    private static func setPipeIntEnable(_ pipe: UInt, bits: UInt32) {
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20 + 0x08, (bits & 0xFF) << 8)
    }

    // MARK: PCFG – Pipe Configuration

    /// PCFG – Pipe `pipe` Configuration Register (raw 8-bit value).
    /// See Section 32.8.25.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name  | R/W | Description                                    |
    /// -----------------------------------------------------------------------
    /// | 6:4  | PTYPE | R/W | Pipe type. See PipeType enum.                  |
    /// -----------------------------------------------------------------------
    /// |  2   | BK    | R/W | Number of banks: 0 = single, 1 = dual.        |
    /// -----------------------------------------------------------------------
    /// | 1:0  | PTOKEN| R/W | Pipe token. See PipeToken enum.                |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static func pipeConfigRegister(pipe: UInt) -> UInt32 {
        _volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20) & 0xFF
    }

    @inline(__always)
    private static func writePipeConfig(_ pipe: UInt, _ value: UInt32) {
        let word = _volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20)
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20, (word & 0xFFFFFF00) | (value & 0xFF))
    }

    /// PCFG.PTOKEN – Pipe Token for pipe `pipe`.
    @inline(__always)
    static func pipeToken(pipe: UInt) -> PipeToken {
        let t = pipeConfigRegister(pipe: pipe) & 0x03
        return PipeToken(rawValue: t) ?? .setup
    }

    @inline(__always)
    static func setPipeToken(pipe: UInt, _ token: PipeToken) {
        let cfg = pipeConfigRegister(pipe: pipe)
        writePipeConfig(pipe, (cfg & ~0x03) | (token.rawValue & 0x03))
    }

    /// PCFG.BK – Dual-Bank Enable for pipe `pipe`.
    @inline(__always)
    static func pipeDualBank(pipe: UInt) -> Bool {
        (pipeConfigRegister(pipe: pipe) & (1 << 2)) != 0
    }

    @inline(__always)
    static func setPipeDualBank(pipe: UInt, _ enabled: Bool) {
        let cfg = pipeConfigRegister(pipe: pipe)
        writePipeConfig(pipe, enabled ? (cfg | (1 << 2)) : (cfg & ~(1 << 2)))
    }

    /// PCFG.PTYPE – Pipe Type for pipe `pipe`.
    @inline(__always)
    static func pipeType(pipe: UInt) -> PipeType {
        let t = (pipeConfigRegister(pipe: pipe) >> 4) & 0x07
        return PipeType(rawValue: t) ?? .disabled
    }

    @inline(__always)
    static func setPipeType(pipe: UInt, _ type: PipeType) {
        let cfg = pipeConfigRegister(pipe: pipe)
        writePipeConfig(pipe, (cfg & ~(0x07 << 4)) | ((`type`.rawValue & 0x07) << 4))
    }


    // MARK: BINTERVAL – Pipe Polling Interval

    /// BINTERVAL – Polling interval in frames for pipe `pipe`.
    /// See Section 32.8.26.
    ///
    /// For interrupt and isochronous pipes, sets the polling period in frames (1–255).
    /// For control and bulk pipes this value is ignored.
    @inline(__always)
    static func pipePollInterval(pipe: UInt) -> UInt32 {
        (_volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20) >> 24) & 0xFF
    }

    @inline(__always)
    static func setPipePollInterval(pipe: UInt, _ interval: UInt32) {
        let word = _volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20)
        _volatileRegisterWriteUInt32(USB_EP_BASE + pipe &* 0x20, (word & 0x00FFFFFF) | ((interval & 0xFF) << 24))
    }


    // MARK: PSTATUS – Pipe Status

    /// Returns the raw PSTATUS byte for pipe `pipe` (bits [23:16] of status word).
    ///
    /// PSTATUS bit positions:
    ///   Bit 7: BK1RDY  – Bank 1 ready.
    ///   Bit 6: BK0RDY  – Bank 0 ready (firmware sets to arm an OUT or IN transfer).
    ///   Bit 4: PFREEZE – Pipe frozen (no transactions issued).
    ///   Bit 2: CURBK   – Current bank (0 or 1, set by hardware in dual-bank).
    ///   Bit 0: DTGL    – Data toggle.
    @inline(__always)
    static func pipeStatus(pipe: UInt) -> UInt32 {
        (_volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20 + 0x04) >> 16) & 0xFF
    }

    /// PSTATUS.DTGL – Data toggle for pipe `pipe`.
    @inline(__always)
    static func pipeDataToggle(pipe: UInt) -> Bool {
        (pipeStatus(pipe: pipe) & (1 << 0)) != 0
    }

    @inline(__always)
    static func setPipeDataToggle(pipe: UInt, _ value: Bool) {
        if value { setPipeStatus(pipe, bits: 1 << 0) }
        else      { clearPipeStatus(pipe, bits: 1 << 0) }
    }

    /// PSTATUS.CURBK – Current bank for pipe `pipe` (read-only in dual-bank mode).
    @inline(__always)
    static func pipeCurrentBank(pipe: UInt) -> UInt {
        (pipeStatus(pipe: pipe) & (1 << 2)) != 0 ? 1 : 0
    }

    /// PSTATUS.PFREEZE – Pipe freeze for pipe `pipe`.
    ///
    /// When set, the pipe is frozen and no USB transactions are generated. Set to pause
    /// a transfer; clear to resume or start.
    @inline(__always)
    static func pipeFrozen(pipe: UInt) -> Bool {
        (pipeStatus(pipe: pipe) & (1 << 4)) != 0
    }

    @inline(__always)
    static func setPipeFrozen(pipe: UInt, _ frozen: Bool) {
        if frozen { setPipeStatus(pipe, bits: 1 << 4) }
        else       { clearPipeStatus(pipe, bits: 1 << 4) }
    }

    /// PSTATUS.BK0RDY – Bank 0 ready for pipe `pipe`.
    ///
    /// For OUT: firmware sets this to arm the bank for transmission.
    /// For IN: hardware sets this when received data is available; firmware clears to re-arm.
    @inline(__always)
    static func pipeBank0Ready(pipe: UInt) -> Bool {
        (pipeStatus(pipe: pipe) & (1 << 6)) != 0
    }

    @inline(__always)
    static func setPipeBank0Ready(pipe: UInt, _ value: Bool) {
        if value { setPipeStatus(pipe, bits: 1 << 6) }
        else      { clearPipeStatus(pipe, bits: 1 << 6) }
    }

    /// PSTATUS.BK1RDY – Bank 1 ready for pipe `pipe`.
    @inline(__always)
    static func pipeBank1Ready(pipe: UInt) -> Bool {
        (pipeStatus(pipe: pipe) & (1 << 7)) != 0
    }

    @inline(__always)
    static func setPipeBank1Ready(pipe: UInt, _ value: Bool) {
        if value { setPipeStatus(pipe, bits: 1 << 7) }
        else      { clearPipeStatus(pipe, bits: 1 << 7) }
    }


    // MARK: PINTFLAG – Pipe Interrupt Flag

    /// Returns the raw PINTFLAG byte for pipe `pipe` (bits [31:24] of status word).
    ///
    /// PINTFLAG bit positions:
    ///   Bit 5: STALL  – STALL received.
    ///   Bit 4: TXSTP  – SETUP token transmitted.
    ///   Bit 3: PERR   – Pipe error (CRC, bit-stuff, data toggle, PID mismatch).
    ///   Bit 2: TRFAIL – Transfer failed (NAK or error retry limit exceeded).
    ///   Bit 1: TRCPT1 – Transfer complete bank 1.
    ///   Bit 0: TRCPT0 – Transfer complete bank 0.
    @inline(__always)
    static func pipeInterruptFlags(pipe: UInt) -> UInt32 {
        (_volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20 + 0x04) >> 24) & 0xFF
    }

    /// PINTFLAG.TRCPT0 – Transfer complete bank 0. Write `true` to clear.
    @inline(__always)
    static func pipeTransferCompleteBank0(pipe: UInt) -> Bool {
        (pipeInterruptFlags(pipe: pipe) & (1 << 0)) != 0
    }

    @inline(__always)
    static func clearPipeTransferCompleteBank0(pipe: UInt) {
        clearPipeIntFlag(pipe, bits: 1 << 0)
    }

    /// PINTFLAG.TRCPT1 – Transfer complete bank 1. Write `true` to clear.
    @inline(__always)
    static func pipeTransferCompleteBank1(pipe: UInt) -> Bool {
        (pipeInterruptFlags(pipe: pipe) & (1 << 1)) != 0
    }

    @inline(__always)
    static func clearPipeTransferCompleteBank1(pipe: UInt) {
        clearPipeIntFlag(pipe, bits: 1 << 1)
    }

    /// PINTFLAG.TRFAIL – Transfer failed. Write `true` to clear.
    @inline(__always)
    static func pipeTransferFailed(pipe: UInt) -> Bool {
        (pipeInterruptFlags(pipe: pipe) & (1 << 2)) != 0
    }

    @inline(__always)
    static func clearPipeTransferFailed(pipe: UInt) {
        clearPipeIntFlag(pipe, bits: 1 << 2)
    }

    /// PINTFLAG.PERR – Pipe error. Write `true` to clear.
    @inline(__always)
    static func pipePipeError(pipe: UInt) -> Bool {
        (pipeInterruptFlags(pipe: pipe) & (1 << 3)) != 0
    }

    @inline(__always)
    static func clearPipePipeError(pipe: UInt) {
        clearPipeIntFlag(pipe, bits: 1 << 3)
    }

    /// PINTFLAG.TXSTP – Setup token transmitted. Write `true` to clear.
    @inline(__always)
    static func pipeSetupTransmitted(pipe: UInt) -> Bool {
        (pipeInterruptFlags(pipe: pipe) & (1 << 4)) != 0
    }

    @inline(__always)
    static func clearPipeSetupTransmitted(pipe: UInt) {
        clearPipeIntFlag(pipe, bits: 1 << 4)
    }

    /// PINTFLAG.STALL – STALL received. Write `true` to clear.
    @inline(__always)
    static func pipeStallReceived(pipe: UInt) -> Bool {
        (pipeInterruptFlags(pipe: pipe) & (1 << 5)) != 0
    }

    @inline(__always)
    static func clearPipeStallReceived(pipe: UInt) {
        clearPipeIntFlag(pipe, bits: 1 << 5)
    }


    // MARK: PINTEN – Pipe Interrupt Enable

    /// Returns the raw PINTENCLR byte for pipe `pipe` (bits [7:0] of interrupt word).
    ///
    /// Bit layout mirrors PINTFLAG: TRCPT0[0], TRCPT1[1], TRFAIL[2], PERR[3], TXSTP[4], STALL[5].
    @inline(__always)
    static func pipeInterruptEnable(pipe: UInt) -> UInt32 {
        _volatileRegisterReadUInt32(USB_EP_BASE + pipe &* 0x20 + 0x08) & 0xFF
    }

    @inline(__always)
    private static func pipeIntEnabled(pipe: UInt, bit: UInt32) -> Bool {
        (pipeInterruptEnable(pipe: pipe) & (1 << bit)) != 0
    }

    @inline(__always)
    private static func setPipeIntEnabled(pipe: UInt, bit: UInt32, _ enabled: Bool) {
        if enabled { setPipeIntEnable(pipe, bits: 1 << bit) }
        else        { clearPipeIntEnable(pipe, bits: 1 << bit) }
    }

    /// PINTEN.TRCPT0 – Transfer complete bank 0 interrupt enable for pipe `pipe`.
    @inline(__always)
    static func pipeTransferCompleteBank0InterruptEnable(pipe: UInt) -> Bool {
        pipeIntEnabled(pipe: pipe, bit: 0)
    }

    @inline(__always)
    static func setPipeTransferCompleteBank0InterruptEnable(pipe: UInt, _ enabled: Bool) {
        setPipeIntEnabled(pipe: pipe, bit: 0, enabled)
    }

    /// PINTEN.TRCPT1 – Transfer complete bank 1 interrupt enable for pipe `pipe`.
    @inline(__always)
    static func pipeTransferCompleteBank1InterruptEnable(pipe: UInt) -> Bool {
        pipeIntEnabled(pipe: pipe, bit: 1)
    }

    @inline(__always)
    static func setPipeTransferCompleteBank1InterruptEnable(pipe: UInt, _ enabled: Bool) {
        setPipeIntEnabled(pipe: pipe, bit: 1, enabled)
    }

    /// PINTEN.TRFAIL – Transfer failed interrupt enable for pipe `pipe`.
    @inline(__always)
    static func pipeTransferFailedInterruptEnable(pipe: UInt) -> Bool {
        pipeIntEnabled(pipe: pipe, bit: 2)
    }

    @inline(__always)
    static func setPipeTransferFailedInterruptEnable(pipe: UInt, _ enabled: Bool) {
        setPipeIntEnabled(pipe: pipe, bit: 2, enabled)
    }

    /// PINTEN.PERR – Pipe error interrupt enable for pipe `pipe`.
    @inline(__always)
    static func pipePipeErrorInterruptEnable(pipe: UInt) -> Bool {
        pipeIntEnabled(pipe: pipe, bit: 3)
    }

    @inline(__always)
    static func setPipePipeErrorInterruptEnable(pipe: UInt, _ enabled: Bool) {
        setPipeIntEnabled(pipe: pipe, bit: 3, enabled)
    }

    /// PINTEN.TXSTP – Setup transmitted interrupt enable for pipe `pipe`.
    @inline(__always)
    static func pipeSetupTransmittedInterruptEnable(pipe: UInt) -> Bool {
        pipeIntEnabled(pipe: pipe, bit: 4)
    }

    @inline(__always)
    static func setPipeSetupTransmittedInterruptEnable(pipe: UInt, _ enabled: Bool) {
        setPipeIntEnabled(pipe: pipe, bit: 4, enabled)
    }

    /// PINTEN.STALL – STALL received interrupt enable for pipe `pipe`.
    @inline(__always)
    static func pipeStallReceivedInterruptEnable(pipe: UInt) -> Bool {
        pipeIntEnabled(pipe: pipe, bit: 5)
    }

    @inline(__always)
    static func setPipeStallReceivedInterruptEnable(pipe: UInt, _ enabled: Bool) {
        setPipeIntEnabled(pipe: pipe, bit: 5, enabled)
    }
}
