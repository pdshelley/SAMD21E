//
//  PowerManager.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/18/26.
//

@usableFromInline let PM_BASE: UInt = 0x40000400   // SAMD21 datasheet §16.8

/// Power Manager
///
/// The Power Manager (PM) controls sleep modes, clock prescalers for the CPU and APB buses,
/// peripheral clock gating (AHB/APBA/APBB/APBC mask registers), clock-change interrupts,
/// Clock Failure Detector interrupts, and the reset-cause register.
///
/// Typical usage patterns:
///   - Enable a peripheral's APB clock before configuring it:
///       `PowerManager.sercom0ClockEnable = true`
///   - Change the CPU clock divider, then wait for the change to propagate:
///       `PowerManager.cpuDivider = .div2`
///       `while !PowerManager.clockReady { }`
///   - After any reset, read RCAUSE to find out why the device was reset:
///       `if PowerManager.wasPowerOnReset { … }`
///
/// See SAMD21 datasheet Section 16.
struct PowerManager {

    // MARK: - Supporting Enums

    /// Idle sleep mode depth (SLEEP.IDLE).
    /// Selects which clock domains are stopped when the CPU executes a WFI/WFE instruction.
    /// See SAMD21 datasheet Section 16.6.3 and Table 16-4.
    enum IdleMode: UInt32 {
        /// Stop the CPU clock only; AHB and APB clocks continue running.
        case cpu = 0
        /// Stop the CPU and AHB clocks; APB clocks continue running.
        case ahb = 1
        /// Stop the CPU, AHB, and APB clocks.
        case apb = 2
    }

    /// Clock prescaler division for the CPU, APBA, APBB, and APBC buses.
    /// See SAMD21 datasheet Section 16.8.5–16.8.8 and Table 16-6.
    enum ClockDivider: UInt32 {
        case div1   = 0   ///< No prescaling (÷1)
        case div2   = 1   ///< ÷2
        case div4   = 2   ///< ÷4
        case div8   = 3   ///< ÷8
        case div16  = 4   ///< ÷16
        case div32  = 5   ///< ÷32
        case div64  = 6   ///< ÷64
        case div128 = 7   ///< ÷128
    }


    // MARK: - CTRL / SLEEP / EXTCTRL (Offset 0x00, little-endian 32-bit word)
    //
    // Three 8-bit registers share the 32-bit word at PM_BASE + 0x00 (little-endian):
    //   Bits  [7:0]  = CTRL    (offset 0x00, R/W 8-bit)
    //   Bits [15:8]  = SLEEP   (offset 0x01, R/W 8-bit)
    //   Bits [23:16] = EXTCTRL (offset 0x02, R/W 8-bit)
    //
    // All sub-register properties use a 32-bit read-modify-write so only their own
    // field is changed and the sibling registers are left intact.

    /// CTRL – Control Register
    /// See Section 16.8.1.
    ///
    /// Raw 8-bit value of the CTRL register, read from bits [7:0] of the 32-bit word at PM_BASE.
    /// Writes perform a 32-bit read-modify-write that preserves the SLEEP and EXTCTRL fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  2  | CFDEN   | R/W | Clock Failure Detector Enable                 |
    /// -----------------------------------------------------------------------
    /// |  5  | BKUPCLK | R/W | Backup Clock Select for the CFD              |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var controlRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE)
            _volatileRegisterWriteUInt32(PM_BASE, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// CTRL.CFDEN – Clock Failure Detector Enable
    /// See Section 16.8.1.
    ///
    /// When set, the Clock Failure Detector (CFD) monitors the main clock. If the main clock
    /// stops, the CFD automatically switches to OSCULP32K, sets the CFD interrupt flag, and
    /// optionally generates an interrupt.
    /// ```
    /// --------------------------------------------------
    /// | Value | Description                            |
    /// --------------------------------------------------
    /// |   0   | Clock Failure Detector disabled.       |
    /// --------------------------------------------------
    /// |   1   | Clock Failure Detector enabled.        |
    /// --------------------------------------------------
    /// ```
    @inline(__always)
    static var clockFailureDetectorEnable: Bool {
        get {
            (controlRegister & (1 << 2)) != 0
        }
        set {
            controlRegister = newValue
                ? (controlRegister | (1 << 2))
                : (controlRegister & ~(1 << 2))
        }
    }

    /// CTRL.BKUPCLK – Backup Clock Select
    /// See Section 16.8.1.
    ///
    /// Selects the clock source used as the backup when the Clock Failure Detector triggers.
    /// ```
    /// -----------------------------------------------------------
    /// | Value | Description                                     |
    /// -----------------------------------------------------------
    /// |   0   | OSCULP32K is used as the backup clock.         |
    /// -----------------------------------------------------------
    /// |   1   | OSCULP32K via the GCLK generator is used.      |
    /// -----------------------------------------------------------
    /// ```
    @inline(__always)
    static var backupClockSelect: Bool {
        get {
            (controlRegister & (1 << 5)) != 0
        }
        set {
            controlRegister = newValue
                ? (controlRegister | (1 << 5))
                : (controlRegister & ~(1 << 5))
        }
    }


    // MARK: - SLEEP – Sleep Mode Register (Offset 0x01, 8-bit)

    /// SLEEP – Sleep Mode Register
    /// See Section 16.8.2.
    ///
    /// Raw 8-bit value of the SLEEP register, read from bits [15:8] of the 32-bit word at PM_BASE.
    /// Writes perform a 32-bit read-modify-write that preserves the CTRL and EXTCTRL fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// | 1:0  | IDLE | R/W | Idle sleep depth selection. See IdleMode enum.  |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var sleepRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE) >> 8) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE)
            _volatileRegisterWriteUInt32(PM_BASE, (word & 0xFFFF00FF) | ((newValue & 0xFF) << 8))
        }
    }

    /// SLEEP.IDLE – Idle Mode Configuration
    /// See Section 16.8.2 and Table 16-4.
    ///
    /// Controls which clocks are stopped when the device enters Idle sleep via WFI/WFE.
    /// ```
    /// -----------------------------------------------------------------
    /// | Value | Name | Description                                    |
    /// -----------------------------------------------------------------
    /// |   0   | CPU  | Stop the CPU clock.                            |
    /// -----------------------------------------------------------------
    /// |   1   | AHB  | Stop the CPU and AHB clocks.                   |
    /// -----------------------------------------------------------------
    /// |   2   | APB  | Stop the CPU, AHB, and APB clocks.             |
    /// -----------------------------------------------------------------
    /// ```
    @inline(__always)
    static var idleMode: IdleMode {
        get {
            let mode = sleepRegister & 0x03
            return IdleMode(rawValue: mode) ?? .cpu
        }
        set {
            sleepRegister = (sleepRegister & ~0x03) | (newValue.rawValue & 0x03)
        }
    }


    // MARK: - EXTCTRL – External Reset Controller Register (Offset 0x02, 8-bit)

    /// EXTCTRL – External Reset Controller Register
    /// See Section 16.8.3.
    ///
    /// Raw 8-bit value of the EXTCTRL register, read from bits [23:16] of the 32-bit word at PM_BASE.
    /// Writes perform a 32-bit read-modify-write that preserves the CTRL and SLEEP fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name   | R/W | Description                                    |
    /// -----------------------------------------------------------------------
    /// |  0  | SETDIS | R/W | '1' disables the external reset on RESETN pin. |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var externalResetControlRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE) >> 16) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE)
            _volatileRegisterWriteUInt32(PM_BASE, (word & 0xFF00FFFF) | ((newValue & 0xFF) << 16))
        }
    }

    /// EXTCTRL.SETDIS – External Reset Disable
    /// See Section 16.8.3.
    ///
    /// When set, the RESET pin no longer triggers a system reset, freeing it for use as a
    /// general-purpose input or for other purposes.
    /// ```
    /// ---------------------------------------------------------------
    /// | Value | Description                                         |
    /// ---------------------------------------------------------------
    /// |   0   | External reset function enabled (normal operation). |
    /// ---------------------------------------------------------------
    /// |   1   | External reset function disabled.                   |
    /// ---------------------------------------------------------------
    /// ```
    @inline(__always)
    static var externalResetDisable: Bool {
        get {
            (externalResetControlRegister & 0x01) != 0
        }
        set {
            externalResetControlRegister = newValue
                ? (externalResetControlRegister | 0x01)
                : (externalResetControlRegister & ~0x01)
        }
    }


    // MARK: - CPUSEL / APBASEL / APBBSEL / APBCSEL (Offset 0x08, little-endian 32-bit word)
    //
    // Four 8-bit prescaler registers share the 32-bit word at PM_BASE + 0x08:
    //   Bits  [7:0]  = CPUSEL  (offset 0x08, R/W 8-bit)
    //   Bits [15:8]  = APBASEL (offset 0x09, R/W 8-bit)
    //   Bits [23:16] = APBBSEL (offset 0x0A, R/W 8-bit)
    //   Bits [31:24] = APBCSEL (offset 0x0B, R/W 8-bit)

    /// CPUSEL – CPU Clock Select Register
    /// See Section 16.8.5.
    ///
    /// Raw 8-bit value of CPUSEL, read from bits [7:0] of the 32-bit word at PM_BASE + 0x08.
    /// Writes perform a 32-bit read-modify-write that preserves the APBA/APBB/APBC select fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name   | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// | 2:0  | CPUDIV | R/W | CPU clock prescaler. See ClockDivider enum.   |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var cpuClockSelectRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x08) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE + 0x08)
            _volatileRegisterWriteUInt32(PM_BASE + 0x08, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// CPUSEL.CPUDIV – CPU Prescaler Selection
    /// See Section 16.8.5 and Table 16-6.
    ///
    /// Sets the division factor applied to the main clock before it reaches the CPU.
    /// Poll `clockReady` after writing to confirm the new clock is active.
    /// ```
    /// -----------------------------------------------
    /// | Value | Name   | Description                |
    /// -----------------------------------------------
    /// |   0   | DIV1   | CPU clock = main clock ÷1  |
    /// -----------------------------------------------
    /// |   1   | DIV2   | CPU clock = main clock ÷2  |
    /// -----------------------------------------------
    /// |   2   | DIV4   | CPU clock = main clock ÷4  |
    /// -----------------------------------------------
    /// |   3   | DIV8   | CPU clock = main clock ÷8  |
    /// -----------------------------------------------
    /// |   4   | DIV16  | CPU clock = main clock ÷16 |
    /// -----------------------------------------------
    /// |   5   | DIV32  | CPU clock = main clock ÷32 |
    /// -----------------------------------------------
    /// |   6   | DIV64  | CPU clock = main clock ÷64 |
    /// -----------------------------------------------
    /// |   7   | DIV128 | CPU clock = main clock ÷128|
    /// -----------------------------------------------
    /// ```
    @inline(__always)
    static var cpuDivider: ClockDivider {
        get {
            let div = cpuClockSelectRegister & 0x07
            return ClockDivider(rawValue: div) ?? .div1
        }
        set {
            cpuClockSelectRegister = (cpuClockSelectRegister & ~0x07) | (newValue.rawValue & 0x07)
        }
    }


    // MARK: - APBASEL – APBA Clock Select Register (Offset 0x09, 8-bit)

    /// APBASEL – APBA Clock Select Register
    /// See Section 16.8.6.
    ///
    /// Raw 8-bit value of APBASEL, read from bits [15:8] of the 32-bit word at PM_BASE + 0x08.
    /// Writes perform a 32-bit read-modify-write that preserves the other select fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// | 2:0  | APBADIV | R/W | APBA clock prescaler. See ClockDivider enum.  |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var apbaClockSelectRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE + 0x08) >> 8) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE + 0x08)
            _volatileRegisterWriteUInt32(PM_BASE + 0x08, (word & 0xFFFF00FF) | ((newValue & 0xFF) << 8))
        }
    }

    /// APBASEL.APBADIV – APBA Prescaler Selection
    /// See Section 16.8.6 and Table 16-6.
    ///
    /// Sets the division factor for the APBA bus clock, which feeds PAC0, PM, SYSCTRL,
    /// GCLK, WDT, RTC, and EIC. Poll `clockReady` after writing.
    @inline(__always)
    static var apbaDivider: ClockDivider {
        get {
            let div = apbaClockSelectRegister & 0x07
            return ClockDivider(rawValue: div) ?? .div1
        }
        set {
            apbaClockSelectRegister = (apbaClockSelectRegister & ~0x07) | (newValue.rawValue & 0x07)
        }
    }


    // MARK: - APBBSEL – APBB Clock Select Register (Offset 0x0A, 8-bit)

    /// APBBSEL – APBB Clock Select Register
    /// See Section 16.8.7.
    ///
    /// Raw 8-bit value of APBBSEL, read from bits [23:16] of the 32-bit word at PM_BASE + 0x08.
    /// Writes perform a 32-bit read-modify-write that preserves the other select fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// | 2:0  | APBBDIV | R/W | APBB clock prescaler. See ClockDivider enum.  |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var apbbClockSelectRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE + 0x08) >> 16) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE + 0x08)
            _volatileRegisterWriteUInt32(PM_BASE + 0x08, (word & 0xFF00FFFF) | ((newValue & 0xFF) << 16))
        }
    }

    /// APBBSEL.APBBDIV – APBB Prescaler Selection
    /// See Section 16.8.7 and Table 16-6.
    ///
    /// Sets the division factor for the APBB bus clock, which feeds PAC1, DSU, NVMCTRL,
    /// PORT, DMAC, USB, and HMATRIX. Poll `clockReady` after writing.
    @inline(__always)
    static var apbbDivider: ClockDivider {
        get {
            let div = apbbClockSelectRegister & 0x07
            return ClockDivider(rawValue: div) ?? .div1
        }
        set {
            apbbClockSelectRegister = (apbbClockSelectRegister & ~0x07) | (newValue.rawValue & 0x07)
        }
    }


    // MARK: - APBCSEL – APBC Clock Select Register (Offset 0x0B, 8-bit)

    /// APBCSEL – APBC Clock Select Register
    /// See Section 16.8.8.
    ///
    /// Raw 8-bit value of APBCSEL, read from bits [31:24] of the 32-bit word at PM_BASE + 0x08.
    /// Writes perform a 32-bit read-modify-write that preserves the other select fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// | 2:0  | APBCDIV | R/W | APBC clock prescaler. See ClockDivider enum.  |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var apbcClockSelectRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE + 0x08) >> 24) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(PM_BASE + 0x08)
            _volatileRegisterWriteUInt32(PM_BASE + 0x08, (word & 0x00FFFFFF) | ((newValue & 0xFF) << 24))
        }
    }

    /// APBCSEL.APBCDIV – APBC Prescaler Selection
    /// See Section 16.8.8 and Table 16-6.
    ///
    /// Sets the division factor for the APBC bus clock, which feeds the majority of
    /// peripherals: all SERCOM instances, TCC0–2, TC3–7, ADC, AC, DAC, PTC, I2S, and AC1.
    /// Poll `clockReady` after writing.
    @inline(__always)
    static var apbcDivider: ClockDivider {
        get {
            let div = apbcClockSelectRegister & 0x07
            return ClockDivider(rawValue: div) ?? .div1
        }
        set {
            apbcClockSelectRegister = (apbcClockSelectRegister & ~0x07) | (newValue.rawValue & 0x07)
        }
    }


    // MARK: - AHBMASK – AHB Mask Register (Offset 0x14, 32-bit)

    /// AHBMASK – AHB Mask Register
    /// See Section 16.8.9.
    ///
    /// Controls clock gating for peripherals on the AHB bus. Setting a bit enables the
    /// corresponding peripheral's AHB clock; clearing it gates (stops) the clock to save power.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  0  | HPB0    | R/W | HPB0 AHB clock enable (APBA bridge)           |
    /// -----------------------------------------------------------------------
    /// |  1  | HPB1    | R/W | HPB1 AHB clock enable (APBB bridge)           |
    /// -----------------------------------------------------------------------
    /// |  2  | HPB2    | R/W | HPB2 AHB clock enable (APBC bridge)           |
    /// -----------------------------------------------------------------------
    /// |  3  | DSU     | R/W | DSU AHB clock enable                          |
    /// -----------------------------------------------------------------------
    /// |  4  | NVMCTRL | R/W | NVMCTRL AHB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  5  | DMAC    | R/W | DMAC AHB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  6  | USB     | R/W | USB AHB clock enable                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var ahbMaskRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x14)
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x14, newValue)
        }
    }

    /// AHBMASK.HPB0 – HPB0 AHB Clock Enable
    /// Enables the AHB clock for High-Performance Bus Bridge 0 (access to APBA peripherals).
    @inline(__always)
    static var hpb0ClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 0)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 0))
                : (ahbMaskRegister & ~(1 << 0))
        }
    }

    /// AHBMASK.HPB1 – HPB1 AHB Clock Enable
    /// Enables the AHB clock for High-Performance Bus Bridge 1 (access to APBB peripherals).
    @inline(__always)
    static var hpb1ClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 1)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 1))
                : (ahbMaskRegister & ~(1 << 1))
        }
    }

    /// AHBMASK.HPB2 – HPB2 AHB Clock Enable
    /// Enables the AHB clock for High-Performance Bus Bridge 2 (access to APBC peripherals).
    @inline(__always)
    static var hpb2ClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 2)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 2))
                : (ahbMaskRegister & ~(1 << 2))
        }
    }

    /// AHBMASK.DSU – DSU AHB Clock Enable
    /// Enables the AHB clock for the Debug Service Unit (CoreSight debug, CRC, MBIST).
    @inline(__always)
    static var dsuAHBClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 3)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 3))
                : (ahbMaskRegister & ~(1 << 3))
        }
    }

    /// AHBMASK.NVMCTRL – NVMCTRL AHB Clock Enable
    /// Enables the AHB clock for the Non-Volatile Memory Controller.
    @inline(__always)
    static var nvmctrlAHBClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 4)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 4))
                : (ahbMaskRegister & ~(1 << 4))
        }
    }

    /// AHBMASK.DMAC – DMAC AHB Clock Enable
    /// Enables the AHB clock for the Direct Memory Access Controller.
    @inline(__always)
    static var dmacAHBClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 5)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 5))
                : (ahbMaskRegister & ~(1 << 5))
        }
    }

    /// AHBMASK.USB – USB AHB Clock Enable
    /// Enables the AHB clock for the Universal Serial Bus controller.
    @inline(__always)
    static var usbAHBClockEnable: Bool {
        get { (ahbMaskRegister & (1 << 6)) != 0 }
        set {
            ahbMaskRegister = newValue
                ? (ahbMaskRegister | (1 << 6))
                : (ahbMaskRegister & ~(1 << 6))
        }
    }


    // MARK: - APBAMASK – APBA Mask Register (Offset 0x18, 32-bit)

    /// APBAMASK – APBA Mask Register
    /// See Section 16.8.9.
    ///
    /// Controls APB clock gating for peripherals on Bridge A. Setting a bit enables the
    /// peripheral's APB clock; clearing it gates the clock.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  0  | PAC0    | R/W | PAC0 APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  1  | PM      | R/W | PM APB clock enable                           |
    /// -----------------------------------------------------------------------
    /// |  2  | SYSCTRL | R/W | SYSCTRL APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  3  | GCLK    | R/W | GCLK APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  4  | WDT     | R/W | WDT APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// |  5  | RTC     | R/W | RTC APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// |  6  | EIC     | R/W | EIC APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var apbaMaskRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x18)
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x18, newValue)
        }
    }

    /// APBAMASK.PAC0 – PAC0 APB Clock Enable
    @inline(__always)
    static var pac0ClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 0)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 0))
                : (apbaMaskRegister & ~(1 << 0))
        }
    }

    /// APBAMASK.PM – Power Manager APB Clock Enable
    @inline(__always)
    static var pmClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 1)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 1))
                : (apbaMaskRegister & ~(1 << 1))
        }
    }

    /// APBAMASK.SYSCTRL – SYSCTRL APB Clock Enable
    @inline(__always)
    static var sysctrlClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 2)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 2))
                : (apbaMaskRegister & ~(1 << 2))
        }
    }

    /// APBAMASK.GCLK – Generic Clock Controller APB Clock Enable
    @inline(__always)
    static var gclkClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 3)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 3))
                : (apbaMaskRegister & ~(1 << 3))
        }
    }

    /// APBAMASK.WDT – Watchdog Timer APB Clock Enable
    @inline(__always)
    static var wdtClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 4)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 4))
                : (apbaMaskRegister & ~(1 << 4))
        }
    }

    /// APBAMASK.RTC – Real-Time Counter APB Clock Enable
    @inline(__always)
    static var rtcClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 5)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 5))
                : (apbaMaskRegister & ~(1 << 5))
        }
    }

    /// APBAMASK.EIC – External Interrupt Controller APB Clock Enable
    @inline(__always)
    static var eicClockEnable: Bool {
        get { (apbaMaskRegister & (1 << 6)) != 0 }
        set {
            apbaMaskRegister = newValue
                ? (apbaMaskRegister | (1 << 6))
                : (apbaMaskRegister & ~(1 << 6))
        }
    }


    // MARK: - APBBMASK – APBB Mask Register (Offset 0x1C, 32-bit)

    /// APBBMASK – APBB Mask Register
    /// See Section 16.8.9.
    ///
    /// Controls APB clock gating for peripherals on Bridge B.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  0  | PAC1    | R/W | PAC1 APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  1  | DSU     | R/W | DSU APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// |  2  | NVMCTRL | R/W | NVMCTRL APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  3  | PORT    | R/W | PORT APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  4  | DMAC    | R/W | DMAC APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  5  | USB     | R/W | USB APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// |  6  | HMATRIX | R/W | HMATRIX APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var apbbMaskRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x1C)
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x1C, newValue)
        }
    }

    /// APBBMASK.PAC1 – PAC1 APB Clock Enable
    @inline(__always)
    static var pac1ClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 0)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 0))
                : (apbbMaskRegister & ~(1 << 0))
        }
    }

    /// APBBMASK.DSU – DSU APB Clock Enable
    @inline(__always)
    static var dsuClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 1)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 1))
                : (apbbMaskRegister & ~(1 << 1))
        }
    }

    /// APBBMASK.NVMCTRL – Non-Volatile Memory Controller APB Clock Enable
    @inline(__always)
    static var nvmctrlClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 2)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 2))
                : (apbbMaskRegister & ~(1 << 2))
        }
    }

    /// APBBMASK.PORT – PORT APB Clock Enable
    @inline(__always)
    static var portClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 3)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 3))
                : (apbbMaskRegister & ~(1 << 3))
        }
    }

    /// APBBMASK.DMAC – DMAC APB Clock Enable
    @inline(__always)
    static var dmacClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 4)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 4))
                : (apbbMaskRegister & ~(1 << 4))
        }
    }

    /// APBBMASK.USB – USB APB Clock Enable
    @inline(__always)
    static var usbClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 5)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 5))
                : (apbbMaskRegister & ~(1 << 5))
        }
    }

    /// APBBMASK.HMATRIX – HMATRIX APB Clock Enable
    @inline(__always)
    static var hmatrixClockEnable: Bool {
        get { (apbbMaskRegister & (1 << 6)) != 0 }
        set {
            apbbMaskRegister = newValue
                ? (apbbMaskRegister | (1 << 6))
                : (apbbMaskRegister & ~(1 << 6))
        }
    }


    // MARK: - APBCMASK – APBC Mask Register (Offset 0x20, 32-bit)

    /// APBCMASK – APBC Mask Register
    /// See Section 16.8.9.
    ///
    /// Controls APB clock gating for peripherals on Bridge C. This bridge hosts the
    /// majority of the device's peripherals.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  0  | PAC2    | R/W | PAC2 APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  1  | EVSYS   | R/W | Event System APB clock enable                 |
    /// -----------------------------------------------------------------------
    /// |  2  | SERCOM0 | R/W | SERCOM0 APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  3  | SERCOM1 | R/W | SERCOM1 APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  4  | SERCOM2 | R/W | SERCOM2 APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  5  | SERCOM3 | R/W | SERCOM3 APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  6  | SERCOM4 | R/W | SERCOM4 APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  7  | SERCOM5 | R/W | SERCOM5 APB clock enable                      |
    /// -----------------------------------------------------------------------
    /// |  8  | TCC0    | R/W | TCC0 APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// |  9  | TCC1    | R/W | TCC1 APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// | 10  | TCC2    | R/W | TCC2 APB clock enable                         |
    /// -----------------------------------------------------------------------
    /// | 11  | TC3     | R/W | TC3 APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 12  | TC4     | R/W | TC4 APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 13  | TC5     | R/W | TC5 APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 14  | TC6     | R/W | TC6 APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 15  | TC7     | R/W | TC7 APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 16  | ADC     | R/W | ADC APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 17  | AC      | R/W | Analog Comparator APB clock enable            |
    /// -----------------------------------------------------------------------
    /// | 18  | DAC     | R/W | DAC APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 19  | PTC     | R/W | Peripheral Touch Controller APB clock enable  |
    /// -----------------------------------------------------------------------
    /// | 20  | I2S     | R/W | I2S APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// | 21  | AC1     | R/W | AC1 APB clock enable                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var apbcMaskRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x20)
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x20, newValue)
        }
    }

    /// APBCMASK.PAC2 – PAC2 APB Clock Enable
    @inline(__always)
    static var pac2ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 0)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 0))
                : (apbcMaskRegister & ~(1 << 0))
        }
    }

    /// APBCMASK.EVSYS – Event System APB Clock Enable
    @inline(__always)
    static var evsysClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 1)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 1))
                : (apbcMaskRegister & ~(1 << 1))
        }
    }

    /// APBCMASK.SERCOM0 – SERCOM0 APB Clock Enable
    @inline(__always)
    static var sercom0ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 2)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 2))
                : (apbcMaskRegister & ~(1 << 2))
        }
    }

    /// APBCMASK.SERCOM1 – SERCOM1 APB Clock Enable
    @inline(__always)
    static var sercom1ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 3)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 3))
                : (apbcMaskRegister & ~(1 << 3))
        }
    }

    /// APBCMASK.SERCOM2 – SERCOM2 APB Clock Enable
    @inline(__always)
    static var sercom2ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 4)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 4))
                : (apbcMaskRegister & ~(1 << 4))
        }
    }

    /// APBCMASK.SERCOM3 – SERCOM3 APB Clock Enable
    @inline(__always)
    static var sercom3ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 5)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 5))
                : (apbcMaskRegister & ~(1 << 5))
        }
    }

    /// APBCMASK.SERCOM4 – SERCOM4 APB Clock Enable
    @inline(__always)
    static var sercom4ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 6)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 6))
                : (apbcMaskRegister & ~(1 << 6))
        }
    }

    /// APBCMASK.SERCOM5 – SERCOM5 APB Clock Enable
    @inline(__always)
    static var sercom5ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 7)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 7))
                : (apbcMaskRegister & ~(1 << 7))
        }
    }

    /// APBCMASK.TCC0 – TCC0 APB Clock Enable
    @inline(__always)
    static var tcc0ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 8)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 8))
                : (apbcMaskRegister & ~(1 << 8))
        }
    }

    /// APBCMASK.TCC1 – TCC1 APB Clock Enable
    @inline(__always)
    static var tcc1ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 9)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 9))
                : (apbcMaskRegister & ~(1 << 9))
        }
    }

    /// APBCMASK.TCC2 – TCC2 APB Clock Enable
    @inline(__always)
    static var tcc2ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 10)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 10))
                : (apbcMaskRegister & ~(1 << 10))
        }
    }

    /// APBCMASK.TC3 – TC3 APB Clock Enable
    @inline(__always)
    static var tc3ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 11)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 11))
                : (apbcMaskRegister & ~(1 << 11))
        }
    }

    /// APBCMASK.TC4 – TC4 APB Clock Enable
    @inline(__always)
    static var tc4ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 12)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 12))
                : (apbcMaskRegister & ~(1 << 12))
        }
    }

    /// APBCMASK.TC5 – TC5 APB Clock Enable
    @inline(__always)
    static var tc5ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 13)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 13))
                : (apbcMaskRegister & ~(1 << 13))
        }
    }

    /// APBCMASK.TC6 – TC6 APB Clock Enable
    @inline(__always)
    static var tc6ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 14)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 14))
                : (apbcMaskRegister & ~(1 << 14))
        }
    }

    /// APBCMASK.TC7 – TC7 APB Clock Enable
    @inline(__always)
    static var tc7ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 15)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 15))
                : (apbcMaskRegister & ~(1 << 15))
        }
    }

    /// APBCMASK.ADC – Analog-to-Digital Converter APB Clock Enable
    @inline(__always)
    static var adcClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 16)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 16))
                : (apbcMaskRegister & ~(1 << 16))
        }
    }

    /// APBCMASK.AC – Analog Comparator APB Clock Enable
    @inline(__always)
    static var acClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 17)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 17))
                : (apbcMaskRegister & ~(1 << 17))
        }
    }

    /// APBCMASK.DAC – Digital-to-Analog Converter APB Clock Enable
    @inline(__always)
    static var dacClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 18)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 18))
                : (apbcMaskRegister & ~(1 << 18))
        }
    }

    /// APBCMASK.PTC – Peripheral Touch Controller APB Clock Enable
    @inline(__always)
    static var ptcClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 19)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 19))
                : (apbcMaskRegister & ~(1 << 19))
        }
    }

    /// APBCMASK.I2S – I2S APB Clock Enable
    @inline(__always)
    static var i2sClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 20)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 20))
                : (apbcMaskRegister & ~(1 << 20))
        }
    }

    /// APBCMASK.AC1 – AC1 APB Clock Enable
    @inline(__always)
    static var ac1ClockEnable: Bool {
        get { (apbcMaskRegister & (1 << 21)) != 0 }
        set {
            apbcMaskRegister = newValue
                ? (apbcMaskRegister | (1 << 21))
                : (apbcMaskRegister & ~(1 << 21))
        }
    }


    // MARK: - INTENCLR / INTENSET / INTFLAG (Offset 0x34, little-endian 32-bit word)
    //
    // Three 8-bit interrupt registers share the 32-bit word at PM_BASE + 0x34:
    //   Bits  [7:0]  = INTENCLR (offset 0x34, R/W 8-bit — write 1 to clear enable)
    //   Bits [15:8]  = INTENSET (offset 0x35, R/W 8-bit — write 1 to set enable)
    //   Bits [23:16] = INTFLAG  (offset 0x36, R/W 8-bit — write 1 to clear flag)
    //
    // INTENCLR and INTENSET are paired set/clear registers: writing 0 to either has no
    // effect, so no read-modify-write is required. INTFLAG is write-1-to-clear, so
    // writing 0 there is also a no-op. The register properties below write a single
    // 32-bit word that places the desired value in the target byte and zeros everywhere
    // else, avoiding any accidental side-effects on the sibling registers.

    /// INTENCLR – Interrupt Enable Clear Register
    /// See Section 16.8.11.
    ///
    /// Reading returns the current interrupt enable state for both flags.
    /// Writing '1' to a bit disables the corresponding interrupt; writing '0' has no effect.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name  | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// |  0  | CKRDY | R/W | Clock Ready interrupt enable (clear-on-write-1) |
    /// -----------------------------------------------------------------------
    /// |  1  | CFD   | R/W | Clock Failure Detector interrupt enable (c-o-w1)|
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var interruptEnableClearRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x34) & 0x000000FF
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x34, newValue & 0xFF)
        }
    }

    /// INTENSET – Interrupt Enable Set Register
    /// See Section 16.8.12.
    ///
    /// Reading returns the current interrupt enable state for both flags.
    /// Writing '1' to a bit enables the corresponding interrupt; writing '0' has no effect.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name  | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// |  0  | CKRDY | R/W | Clock Ready interrupt enable (set-on-write-1)   |
    /// -----------------------------------------------------------------------
    /// |  1  | CFD   | R/W | Clock Failure Detector interrupt enable (s-o-w1)|
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var interruptEnableSetRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE + 0x34) >> 8) & 0x000000FF
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x34, (newValue & 0xFF) << 8)
        }
    }

    /// INTFLAG – Interrupt Flag Status and Clear Register
    /// See Section 16.8.13.
    ///
    /// Bits are set by hardware when an interrupt condition occurs.
    /// Write '1' to a bit to clear it; writing '0' has no effect.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name  | R/W | Description                                     |
    /// -----------------------------------------------------------------------
    /// |  0  | CKRDY | R/W | Set when all clocks are stable after a change.  |
    /// -----------------------------------------------------------------------
    /// |  1  | CFD   | R/W | Set when the Clock Failure Detector triggers.   |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var interruptFlagRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(PM_BASE + 0x34) >> 16) & 0x000000FF
        }
        set {
            _volatileRegisterWriteUInt32(PM_BASE + 0x34, (newValue & 0xFF) << 16)
        }
    }

    /// CKRDY – Clock Ready Interrupt Enable
    /// See Section 16.8.11–16.8.12.
    ///
    /// When enabled, an interrupt fires after a CPU, APBA, APBB, or APBC clock prescaler
    /// change completes and all affected clocks have stabilized.
    @inline(__always)
    static var clockReadyInterruptEnable: Bool {
        get {
            (interruptEnableClearRegister & (1 << 0)) != 0
        }
        set {
            if newValue {
                interruptEnableSetRegister = (1 << 0)
            } else {
                interruptEnableClearRegister = (1 << 0)
            }
        }
    }

    /// CFD – Clock Failure Detector Interrupt Enable
    /// See Section 16.8.11–16.8.12.
    ///
    /// When enabled, an interrupt fires if the Clock Failure Detector detects that the
    /// main clock has stopped and switches the system to the OSCULP32K backup clock.
    @inline(__always)
    static var clockFailureDetectorInterruptEnable: Bool {
        get {
            (interruptEnableClearRegister & (1 << 1)) != 0
        }
        set {
            if newValue {
                interruptEnableSetRegister = (1 << 1)
            } else {
                interruptEnableClearRegister = (1 << 1)
            }
        }
    }

    /// INTFLAG.CKRDY – Clock Ready Flag
    /// See Section 16.8.13.
    ///
    /// Set by hardware when all clocks have stabilized after a prescaler change.
    /// Write `true` to clear this flag.
    @inline(__always)
    static var clockReady: Bool {
        get { (interruptFlagRegister & (1 << 0)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 0) } }
    }

    /// INTFLAG.CFD – Clock Failure Detector Flag
    /// See Section 16.8.13.
    ///
    /// Set by hardware when the Clock Failure Detector detects a main clock failure and
    /// switches to the backup clock. Write `true` to clear this flag.
    @inline(__always)
    static var clockFailureDetected: Bool {
        get { (interruptFlagRegister & (1 << 1)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 1) } }
    }


    // MARK: - RCAUSE – Reset Cause Register (Offset 0x38, 8-bit, read-only)

    /// RCAUSE – Reset Cause Register
    /// See Section 16.8.14.
    ///
    /// Records the cause of the last system reset. Flags are read-only and are cleared only
    /// by the next reset. Typically only one bit is set at a time.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name  |  R  | Description                                     |
    /// -----------------------------------------------------------------------
    /// |  0  | POR   |  R  | Power-on Reset                                  |
    /// -----------------------------------------------------------------------
    /// |  1  | BOD12 |  R  | 1.2 V Brown-Out Detector Reset                  |
    /// -----------------------------------------------------------------------
    /// |  2  | BOD33 |  R  | 3.3 V Brown-Out Detector Reset                  |
    /// -----------------------------------------------------------------------
    /// |  4  | EXT   |  R  | External Reset (RESET pin asserted)             |
    /// -----------------------------------------------------------------------
    /// |  5  | WDT   |  R  | Watchdog Timer Reset                            |
    /// -----------------------------------------------------------------------
    /// |  6  | SYST  |  R  | System Reset Request (software reset via SCB)   |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var resetCauseRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(PM_BASE + 0x38) & 0x000000FF
        }
    }

    /// RCAUSE.POR – Power-On Reset
    /// Set when the device last reset due to power-on.
    @inline(__always)
    static var wasPowerOnReset: Bool {
        (resetCauseRegister & (1 << 0)) != 0
    }

    /// RCAUSE.BOD12 – 1.2 V Brown-Out Detector Reset
    /// Set when the device last reset because the core voltage fell below 1.2 V.
    @inline(__always)
    static var wasBrownOut12Reset: Bool {
        (resetCauseRegister & (1 << 1)) != 0
    }

    /// RCAUSE.BOD33 – 3.3 V Brown-Out Detector Reset
    /// Set when the device last reset because the supply voltage fell below the BOD33 threshold.
    @inline(__always)
    static var wasBrownOut33Reset: Bool {
        (resetCauseRegister & (1 << 2)) != 0
    }

    /// RCAUSE.EXT – External Reset
    /// Set when the device last reset due to the RESET pin being asserted externally.
    @inline(__always)
    static var wasExternalReset: Bool {
        (resetCauseRegister & (1 << 4)) != 0
    }

    /// RCAUSE.WDT – Watchdog Timer Reset
    /// Set when the device last reset because the Watchdog Timer expired without being cleared.
    @inline(__always)
    static var wasWatchdogReset: Bool {
        (resetCauseRegister & (1 << 5)) != 0
    }

    /// RCAUSE.SYST – System Reset Request
    /// Set when the device last reset due to a software-initiated system reset via the
    /// ARM Cortex-M0+ System Control Block (SCB.AIRCR.SYSRESETREQ).
    @inline(__always)
    static var wasSystemReset: Bool {
        (resetCauseRegister & (1 << 6)) != 0
    }
}
