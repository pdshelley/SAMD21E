//
//  GenericClockController.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/18/26.
//

@usableFromInline let GCLK_BASE: UInt = 0x40000C00   // SAMD21 datasheet §15.8

/// Generic Clock Controller
///
/// The Generic Clock Controller (GCLK) manages the distribution of clocks from various sources
/// to the peripherals on the SAMD21. It consists of Generic Clock Generators (0–8), each of
/// which can be independently configured with a clock source and division factor. Each generator's
/// output can then be routed to one or more peripheral clock inputs via the CLKCTRL register.
///
/// Typical setup sequence:
///   1. Configure a Generator: write GENDIV (division factor), then write GENCTRL (source + enable).
///   2. Wait for SYNCBUSY to clear.
///   3. Route the Generator to a peripheral: write CLKCTRL (generator + peripheral ID + enable).
///
/// See SAMD21 datasheet Section 15.
struct GenericClockController {

    // MARK: - Supporting Enums

    /// Generic Clock Generator selection.
    /// The SAMD21 provides nine independent Generic Clock Generators (0 through 8).
    /// Generator 0 is the main clock generator and has a 16-bit division register;
    /// Generators 1–8 have 8-bit division registers.
    enum Generator: UInt32 {
        case generator0 = 0
        case generator1 = 1
        case generator2 = 2
        case generator3 = 3
        case generator4 = 4
        case generator5 = 5
        case generator6 = 6
        case generator7 = 7
        case generator8 = 8
    }

    /// Clock source selection for a Generic Clock Generator (GENCTRL.SRC).
    /// See SAMD21 datasheet Section 15.8.4 and Table 15-1.
    enum ClockSource: UInt32 {
        /// XOSC: External Crystal Oscillator or clock signal on XIN.
        case externalCrystalOscillator = 0x00
        /// GCLKIN: Input from the GCLK_IO pin of the current generator.
        case generatorInputPad = 0x01
        /// GCLKGEN1: Output of Generic Clock Generator 1.
        case genericClockGenerator1 = 0x02
        /// OSCULP32K: Ultra Low Power 32.768 kHz internal oscillator.
        case ultraLowPower32K = 0x03
        /// OSC32K: 32.768 kHz internal crystal oscillator.
        case internalOscillator32K = 0x04
        /// XOSC32K: 32.768 kHz external crystal oscillator.
        case externalCrystalOscillator32K = 0x05
        /// OSC8M: 8 MHz internal RC oscillator.
        case internalOscillator8M = 0x06
        /// DFLL48M: 48 MHz Digital Frequency Locked Loop.
        case dfll48M = 0x07
        /// FDPLL96M: 96 MHz Fractional Digital Phase-Locked Loop.
        case fdpll96M = 0x08
    }

    /// Peripheral clock input selection for CLKCTRL.ID.
    /// Identifies which peripheral's generic clock input to configure.
    /// See SAMD21 datasheet Section 15.8.3 and Table 15-2.
    enum PeripheralClockID: UInt32 {
        /// DFLL48M reference clock input.
        case dfll48MReference = 0x00
        /// FDPLL96M reference clock input.
        case fdpll96MReference = 0x01
        /// FDPLL96M 32 kHz clock for the internal lock timer.
        case fdpll96MLockTimer = 0x02
        /// Watchdog Timer (WDT).
        case watchdogTimer = 0x03
        /// Real-Time Counter (RTC).
        case realTimeCounter = 0x04
        /// External Interrupt Controller (EIC).
        case externalInterruptController = 0x05
        /// Universal Serial Bus (USB).
        case usb = 0x06
        /// Event System Channel 0.
        case eventSystemChannel0 = 0x07
        /// Event System Channel 1.
        case eventSystemChannel1 = 0x08
        /// Event System Channel 2.
        case eventSystemChannel2 = 0x09
        /// Event System Channel 3.
        case eventSystemChannel3 = 0x0A
        /// Event System Channel 4.
        case eventSystemChannel4 = 0x0B
        /// Event System Channel 5.
        case eventSystemChannel5 = 0x0C
        /// Event System Channel 6.
        case eventSystemChannel6 = 0x0D
        /// Event System Channel 7.
        case eventSystemChannel7 = 0x0E
        /// Event System Channel 8.
        case eventSystemChannel8 = 0x0F
        /// Event System Channel 9.
        case eventSystemChannel9 = 0x10
        /// Event System Channel 10.
        case eventSystemChannel10 = 0x11
        /// Event System Channel 11.
        case eventSystemChannel11 = 0x12
        /// SERCOMx Slow (shared slow clock for all SERCOM instances).
        case sercomSlow = 0x13
        /// SERCOM0 Core clock.
        case sercom0Core = 0x14
        /// SERCOM1 Core clock.
        case sercom1Core = 0x15
        /// SERCOM2 Core clock.
        case sercom2Core = 0x16
        /// SERCOM3 Core clock.
        case sercom3Core = 0x17
        /// SERCOM4 Core clock.
        case sercom4Core = 0x18
        /// SERCOM5 Core clock.
        case sercom5Core = 0x19
        /// TCC0 and TCC1 clock.
        case tcc0AndTcc1 = 0x1A
        /// TCC2 and TC3 clock.
        case tcc2AndTc3 = 0x1B
        /// TC4 and TC5 clock.
        case tc4AndTc5 = 0x1C
        /// TC6 and TC7 clock.
        case tc6AndTc7 = 0x1D
        /// Analog-to-Digital Converter (ADC).
        case analogToDigitalConverter = 0x1E
        /// Analog Comparator digital clock (AC_DIG).
        case analogComparatorDigital = 0x1F
        /// Analog Comparator analog clock (AC_ANA).
        case analogComparatorAnalog = 0x20
        /// Digital-to-Analog Converter (DAC).
        case digitalToAnalogConverter = 0x21
        /// I2S Serial Clock 0.
        case i2sSerialClock0 = 0x23
        /// I2S Serial Clock 1.
        case i2sSerialClock1 = 0x24
    }

    /// Division mode for a Generic Clock Generator (GENCTRL.DIVSEL).
    /// Controls how the GENDIV.DIV value is interpreted.
    /// See SAMD21 datasheet Section 15.8.4.
    enum DivideSelection: UInt32 {
        /// Linear division: f_out = f_src / (DIV+1), or f_src if DIV = 0.
        case linear = 0
        /// Power-of-two division: f_out = f_src / 2^(DIV+1).
        case powerOfTwo = 1
    }


    // MARK: - CTRL – Control Register (Offset 0x00, 8-bit)
    //
    // CTRL, STATUS, and CLKCTRL share one 32-bit-aligned word at GCLK_BASE.
    // Little-endian 32-bit layout at GCLK_BASE:
    //   Bits  [7:0]  = CTRL    (offset 0x00, R/W 8-bit)
    //   Bits [15:8]  = STATUS  (offset 0x01, R   8-bit)
    //   Bits [31:16] = CLKCTRL (offset 0x02, R/W 16-bit)
    //
    // Each register property below performs a 32-bit read-modify-write so that
    // it only affects its own field and leaves the others intact.

    /// CTRL – Control Register
    /// See Section 15.8.1.
    ///
    /// Raw 8-bit value of the CTRL register, read from bits [7:0] of the 32-bit word at GCLK_BASE.
    /// Writes perform a 32-bit read-modify-write that preserves the STATUS and CLKCTRL fields.
    /// ```
    /// -----------------------------------------------------------------------------------------
    /// | Bit   | Name  | R/W | Description                                                    |
    /// -----------------------------------------------------------------------------------------
    /// |   0   | SWRST | R/W | Software Reset – set to trigger a reset of all GCLK registers. |
    /// -----------------------------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var controlRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(GCLK_BASE) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(GCLK_BASE)
            _volatileRegisterWriteUInt32(GCLK_BASE, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// SWRST – Software Reset
    /// See Section 15.8.1.
    ///
    /// Writing '1' to this bit resets all GCLK registers (except DBGCTRL) to their initial state.
    /// The bit reads as '1' while the reset is in progress and is automatically cleared when complete.
    /// ```
    /// -------------------------------------------------------
    /// | Value | Description                                 |
    /// -------------------------------------------------------
    /// |   0   | No effect, or reset has completed.          |
    /// -------------------------------------------------------
    /// |   1   | Reset all GCLK registers.                   |
    /// -------------------------------------------------------
    /// ```
    @inline(__always)
    static var softwareReset: Bool {
        get {
            (controlRegister & 0x01) != 0
        }
        set {
            controlRegister = newValue ? (controlRegister | 0x01) : (controlRegister & ~0x01)
        }
    }


    // MARK: - STATUS – Status Register (Offset 0x01, 8-bit, read-only)

    /// STATUS – Status Register
    /// See Section 15.8.2.
    ///
    /// Raw 8-bit value of the STATUS register, read from bits [15:8] of the 32-bit word at GCLK_BASE.
    /// This register is read-only; writes have no effect.
    /// ```
    /// ---------------------------------------------------------------------------------
    /// | Bit   | Name      | R/W | Description                                         |
    /// ---------------------------------------------------------------------------------
    /// |   7   | SYNCBUSY  |  R  | '1' while a register synchronization is in progress.|
    /// ---------------------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var statusRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(GCLK_BASE) >> 8) & 0x000000FF
        }
    }

    /// SYNCBUSY – Synchronization Busy
    /// See Section 15.8.2.
    ///
    /// Set by hardware while a write to the GENCTRL or GENDIV registers is being synchronized
    /// across clock domains. Software must poll this bit and wait for '0' before issuing the next
    /// write to GENCTRL or GENDIV.
    /// ```
    /// -------------------------------------------------------
    /// | Value | Description                                 |
    /// -------------------------------------------------------
    /// |   0   | No register synchronization in progress.    |
    /// -------------------------------------------------------
    /// |   1   | Register synchronization is in progress.    |
    /// -------------------------------------------------------
    /// ```
    @inline(__always)
    static var synchronizationBusy: Bool {
        get {
            (statusRegister & 0x80) != 0
        }
    }


    // MARK: - CLKCTRL – Generic Clock Control Register (Offset 0x02, 16-bit)

    /// CLKCTRL – Generic Clock Control
    /// See Section 15.8.3.
    ///
    /// Selects a Generic Clock Generator and routes its output to a specific peripheral clock input.
    /// The raw value is the 16-bit CLKCTRL register, returned in bits [15:0] of a UInt32.
    /// Writes perform a 32-bit read-modify-write that preserves the CTRL and STATUS fields.
    ///
    /// Note: If the WRTLOCK bit is set, writes to this register and the corresponding
    /// generator are ignored until the next system reset.
    /// ```
    /// -----------------------------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                                   |
    /// -----------------------------------------------------------------------------------------
    /// |  5:0  | ID      | R/W | Peripheral Clock Selection ID (see PeripheralClockID).        |
    /// -----------------------------------------------------------------------------------------
    /// | 11:8  | GEN     | R/W | Generic Clock Generator Selection (0–8).                     |
    /// -----------------------------------------------------------------------------------------
    /// |  14   | CLKEN   | R/W | '1' enables the generic clock for the selected peripheral.    |
    /// -----------------------------------------------------------------------------------------
    /// |  15   | WRTLOCK | R/W | '1' locks this entry; no further changes until reset.         |
    /// -----------------------------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var clockControlRegister: UInt32 {
        get {
            (_volatileRegisterReadUInt32(GCLK_BASE) >> 16) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(GCLK_BASE)
            _volatileRegisterWriteUInt32(GCLK_BASE, (word & 0x0000FFFF) | ((newValue & 0xFFFF) << 16))
        }
    }

    /// CLKCTRL.ID – Generic Clock Selection ID
    /// See Section 15.8.3.
    ///
    /// Selects which peripheral's generic clock input is connected to the chosen generator.
    /// See the PeripheralClockID enum for all available peripheral IDs.
    @inline(__always)
    static var peripheralClockID: PeripheralClockID {
        get {
            let id = clockControlRegister & 0x3F
            return PeripheralClockID(rawValue: id) ?? .dfll48MReference
        }
        set {
            clockControlRegister = (clockControlRegister & ~0x3F) | (newValue.rawValue & 0x3F)
        }
    }

    /// CLKCTRL.GEN – Generic Clock Generator Selection
    /// See Section 15.8.3.
    ///
    /// Selects which Generic Clock Generator provides the clock for the peripheral chosen by ID.
    /// ```
    /// -------------------------------------------------------
    /// | Value | Description                                 |
    /// -------------------------------------------------------
    /// |  0–8  | Generic Clock Generator 0 through 8.        |
    /// -------------------------------------------------------
    /// ```
    @inline(__always)
    static var clockGenerator: Generator {
        get {
            let gen = (clockControlRegister >> 8) & 0x0F
            return Generator(rawValue: gen) ?? .generator0
        }
        set {
            clockControlRegister = (clockControlRegister & ~(0x0F << 8)) | ((newValue.rawValue & 0x0F) << 8)
        }
    }

    /// CLKCTRL.CLKEN – Clock Enable
    /// See Section 15.8.3.
    ///
    /// Enables or disables the generic clock for the peripheral selected by CLKCTRL.ID.
    /// ```
    /// -------------------------------------------------------
    /// | Value | Description                                 |
    /// -------------------------------------------------------
    /// |   0   | Generic clock for this peripheral disabled. |
    /// -------------------------------------------------------
    /// |   1   | Generic clock for this peripheral enabled.  |
    /// -------------------------------------------------------
    /// ```
    @inline(__always)
    static var clockEnable: Bool {
        get {
            (clockControlRegister & (1 << 14)) != 0
        }
        set {
            clockControlRegister = newValue
                ? (clockControlRegister | (1 << 14))
                : (clockControlRegister & ~(1 << 14))
        }
    }

    /// CLKCTRL.WRTLOCK – Write Lock
    /// See Section 15.8.3.
    ///
    /// When written to '1', the generic clock and this CLKCTRL entry for the selected peripheral
    /// are permanently locked until the next system reset. Writes to CLKCTRL.ID and to the
    /// corresponding generator's GENCTRL and GENDIV registers are ignored while this bit is set.
    /// ```
    /// -------------------------------------------------------------------
    /// | Value | Description                                             |
    /// -------------------------------------------------------------------
    /// |   0   | CLKCTRL and generator registers are not locked.         |
    /// -------------------------------------------------------------------
    /// |   1   | CLKCTRL and generator registers are locked until reset. |
    /// -------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var writeLock: Bool {
        get {
            (clockControlRegister & (1 << 15)) != 0
        }
        set {
            clockControlRegister = newValue
                ? (clockControlRegister | (1 << 15))
                : (clockControlRegister & ~(1 << 15))
        }
    }


    // MARK: - GENCTRL – Generic Clock Generator Control (Offset 0x04, 32-bit)

    /// GENCTRL – Generic Clock Generator Control
    /// See Section 15.8.4.
    ///
    /// Configures a Generic Clock Generator. The ID field [3:0] selects which generator is
    /// written. All settings for the selected generator are written in a single 32-bit operation.
    ///
    /// After writing this register, poll GCLK.synchronizationBusy before writing again.
    ///
    /// When reading: first write the desired generator's ID to GENCTRL (other fields zero),
    /// wait for synchronization, then read the register to retrieve that generator's settings.
    /// ```
    /// ------------------------------------------------------------------------------------------
    /// | Bits  | Name     | R/W | Description                                                   |
    /// ------------------------------------------------------------------------------------------
    /// |  3:0  | ID       | R/W | Generator Selection (0–8).                                    |
    /// ------------------------------------------------------------------------------------------
    /// | 12:8  | SRC      | R/W | Source Clock Selection (see ClockSource enum).                |
    /// ------------------------------------------------------------------------------------------
    /// |  16   | GENEN    | R/W | '1' enables the Generic Clock Generator.                      |
    /// ------------------------------------------------------------------------------------------
    /// |  17   | IDC      | R/W | '1' forces 50/50 duty cycle for all division factors.         |
    /// ------------------------------------------------------------------------------------------
    /// |  18   | OOV      | R/W | Output level when generator is disabled or stopped.           |
    /// ------------------------------------------------------------------------------------------
    /// |  19   | OE       | R/W | '1' routes generator output to GCLK_IO pin.                  |
    /// ------------------------------------------------------------------------------------------
    /// |  20   | DIVSEL   | R/W | Division mode: 0 = linear, 1 = power-of-two.                 |
    /// ------------------------------------------------------------------------------------------
    /// |  21   | RUNSTDBY | R/W | '1' keeps generator running in Standby sleep mode.            |
    /// ------------------------------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var generatorControl: UInt32 {
        get {
            _volatileRegisterReadUInt32(GCLK_BASE + 0x04)
        }
        set {
            _volatileRegisterWriteUInt32(GCLK_BASE + 0x04, newValue)
        }
    }

    /// GENCTRL.ID – Generator Selection
    /// See Section 15.8.4.
    ///
    /// Selects which Generic Clock Generator is configured by a write to GENCTRL,
    /// or which generator's settings are returned by a read.
    @inline(__always)
    static var generatorID: Generator {
        get {
            let id = generatorControl & 0x0F
            return Generator(rawValue: id) ?? .generator0
        }
        set {
            generatorControl = (generatorControl & ~0x0F) | (newValue.rawValue & 0x0F)
        }
    }

    /// GENCTRL.SRC – Source Clock Selection
    /// See Section 15.8.4 and Table 15-1.
    ///
    /// Selects the source clock fed into the selected Generic Clock Generator.
    /// ```
    /// ---------------------------------------------------------------
    /// | Value | Name        | Description                           |
    /// ---------------------------------------------------------------
    /// |  0x00 | XOSC        | External Crystal Oscillator           |
    /// ---------------------------------------------------------------
    /// |  0x01 | GCLKIN      | Generator Input Pad                   |
    /// ---------------------------------------------------------------
    /// |  0x02 | GCLKGEN1    | Generic Clock Generator 1 Output      |
    /// ---------------------------------------------------------------
    /// |  0x03 | OSCULP32K   | Ultra Low Power 32.768 kHz Oscillator |
    /// ---------------------------------------------------------------
    /// |  0x04 | OSC32K      | 32.768 kHz Internal Oscillator        |
    /// ---------------------------------------------------------------
    /// |  0x05 | XOSC32K     | 32.768 kHz External Crystal Oscillator|
    /// ---------------------------------------------------------------
    /// |  0x06 | OSC8M       | 8 MHz Internal RC Oscillator          |
    /// ---------------------------------------------------------------
    /// |  0x07 | DFLL48M     | 48 MHz Digital Frequency Locked Loop  |
    /// ---------------------------------------------------------------
    /// |  0x08 | FDPLL96M    | 96 MHz Fractional Digital PLL         |
    /// ---------------------------------------------------------------
    /// ```
    @inline(__always)
    static var clockSource: ClockSource {
        get {
            let src = (generatorControl >> 8) & 0x1F
            return ClockSource(rawValue: src) ?? .internalOscillator8M
        }
        set {
            generatorControl = (generatorControl & ~(0x1F << 8)) | ((newValue.rawValue & 0x1F) << 8)
        }
    }

    /// GENCTRL.GENEN – Generic Clock Generator Enable
    /// See Section 15.8.4.
    ///
    /// Enables or disables the selected Generic Clock Generator.
    /// ```
    /// -----------------------------------------------------------
    /// | Value | Description                                     |
    /// -----------------------------------------------------------
    /// |   0   | Generic Clock Generator is disabled.            |
    /// -----------------------------------------------------------
    /// |   1   | Generic Clock Generator is enabled.             |
    /// -----------------------------------------------------------
    /// ```
    @inline(__always)
    static var generatorEnable: Bool {
        get {
            (generatorControl & (1 << 16)) != 0
        }
        set {
            generatorControl = newValue
                ? (generatorControl | (1 << 16))
                : (generatorControl & ~(1 << 16))
        }
    }

    /// GENCTRL.IDC – Improve Duty Cycle
    /// See Section 15.8.4.
    ///
    /// When set, the Generic Clock Generator output has a 50/50 duty cycle for all division
    /// factors. When clear, the duty cycle may differ from 50/50 for odd division factors.
    /// ```
    /// ----------------------------------------------------------------
    /// | Value | Description                                          |
    /// ----------------------------------------------------------------
    /// |   0   | 50/50 duty cycle only guaranteed for even divisors.  |
    /// ----------------------------------------------------------------
    /// |   1   | 50/50 duty cycle guaranteed for all division factors. |
    /// ----------------------------------------------------------------
    /// ```
    @inline(__always)
    static var improveDutyCycle: Bool {
        get {
            (generatorControl & (1 << 17)) != 0
        }
        set {
            generatorControl = newValue
                ? (generatorControl | (1 << 17))
                : (generatorControl & ~(1 << 17))
        }
    }

    /// GENCTRL.OOV – Output Off Value
    /// See Section 15.8.4.
    ///
    /// Sets the logic level driven on the GCLK_IO pin when the Generic Clock Generator is
    /// disabled or when the generator is stopped (e.g., in a sleep mode where RUNSTDBY = 0).
    /// ```
    /// ----------------------------------------------------------
    /// | Value | Description                                    |
    /// ----------------------------------------------------------
    /// |   0   | GCLK_IO output is driven low when disabled.   |
    /// ----------------------------------------------------------
    /// |   1   | GCLK_IO output is driven high when disabled.  |
    /// ----------------------------------------------------------
    /// ```
    @inline(__always)
    static var outputOffValue: Bool {
        get {
            (generatorControl & (1 << 18)) != 0
        }
        set {
            generatorControl = newValue
                ? (generatorControl | (1 << 18))
                : (generatorControl & ~(1 << 18))
        }
    }

    /// GENCTRL.OE – Output Enable
    /// See Section 15.8.4.
    ///
    /// When set, the Generic Clock Generator output is also driven on the GCLK_IO pin, making
    /// the generated clock visible externally. When clear, the generator output is used
    /// internally only and the GCLK_IO pin is not driven by the generator.
    /// ```
    /// --------------------------------------------------------------
    /// | Value | Description                                        |
    /// --------------------------------------------------------------
    /// |   0   | Generator output used internally only.            |
    /// --------------------------------------------------------------
    /// |   1   | Generator output also driven on GCLK_IO pin.      |
    /// --------------------------------------------------------------
    /// ```
    @inline(__always)
    static var outputEnable: Bool {
        get {
            (generatorControl & (1 << 19)) != 0
        }
        set {
            generatorControl = newValue
                ? (generatorControl | (1 << 19))
                : (generatorControl & ~(1 << 19))
        }
    }

    /// GENCTRL.DIVSEL – Divide Selection
    /// See Section 15.8.4.
    ///
    /// Controls how the division factor written to GENDIV.DIV is applied.
    /// ```
    /// ------------------------------------------------------------------------------------------
    /// | Value | Name      | Description                                                        |
    /// ------------------------------------------------------------------------------------------
    /// |   0   | LINEAR    | f_out = f_src / (DIV+1). If DIV=0, no division is applied.        |
    /// ------------------------------------------------------------------------------------------
    /// |   1   | POWER2    | f_out = f_src / 2^(DIV+1). DIV=0 gives a divide-by-2.             |
    /// ------------------------------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var divideSelection: DivideSelection {
        get {
            let sel = (generatorControl >> 20) & 0x01
            return DivideSelection(rawValue: sel) ?? .linear
        }
        set {
            generatorControl = (generatorControl & ~(1 << 20)) | ((newValue.rawValue & 0x01) << 20)
        }
    }

    /// GENCTRL.RUNSTDBY – Run in Standby
    /// See Section 15.8.4.
    ///
    /// When set, the selected Generic Clock Generator continues to run during Standby sleep mode.
    /// When clear, the generator is halted when the device enters Standby.
    /// ```
    /// ---------------------------------------------------------------
    /// | Value | Description                                         |
    /// ---------------------------------------------------------------
    /// |   0   | Generator is halted in Standby sleep mode.         |
    /// ---------------------------------------------------------------
    /// |   1   | Generator continues running in Standby sleep mode. |
    /// ---------------------------------------------------------------
    /// ```
    @inline(__always)
    static var runInStandby: Bool {
        get {
            (generatorControl & (1 << 21)) != 0
        }
        set {
            generatorControl = newValue
                ? (generatorControl | (1 << 21))
                : (generatorControl & ~(1 << 21))
        }
    }


    // MARK: - GENDIV – Generic Clock Generator Division (Offset 0x08, 32-bit)

    /// GENDIV – Generic Clock Generator Division
    /// See Section 15.8.5.
    ///
    /// Sets the clock division factor for a Generic Clock Generator. The ID field [3:0] selects
    /// which generator is configured. The DIV field [23:8] specifies the division factor.
    ///
    /// The effective division depends on GENCTRL.DIVSEL for the selected generator:
    ///   - DIVSEL = 0 (Linear):       f_out = f_src / (DIV+1), or f_src if DIV = 0
    ///   - DIVSEL = 1 (Power of Two): f_out = f_src / 2^(DIV+1)
    ///
    /// Generator 0 supports a 16-bit DIV field (bits [23:8]).
    /// Generators 1–8 support an 8-bit DIV field (bits [15:8]); bits [23:16] are ignored.
    ///
    /// After writing this register, poll GCLK.synchronizationBusy before writing GENCTRL.
    /// ```
    /// ------------------------------------------------------------------------
    /// | Bits  | Name | R/W | Description                                      |
    /// ------------------------------------------------------------------------
    /// |  3:0  | ID   | R/W | Generator Selection (0–8).                       |
    /// ------------------------------------------------------------------------
    /// | 23:8  | DIV  | R/W | Division Factor (16-bit for Gen 0, 8-bit others).|
    /// ------------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var generatorDivision: UInt32 {
        get {
            _volatileRegisterReadUInt32(GCLK_BASE + 0x08)
        }
        set {
            _volatileRegisterWriteUInt32(GCLK_BASE + 0x08, newValue)
        }
    }

    /// GENDIV.ID – Generator Selection
    /// See Section 15.8.5.
    ///
    /// Selects which Generic Clock Generator's division factor is read from or written to.
    @inline(__always)
    static var divisionGeneratorID: Generator {
        get {
            let id = generatorDivision & 0x0F
            return Generator(rawValue: id) ?? .generator0
        }
        set {
            generatorDivision = (generatorDivision & ~0x0F) | (newValue.rawValue & 0x0F)
        }
    }

    /// GENDIV.DIV – Division Factor
    /// See Section 15.8.5.
    ///
    /// Sets the division factor for the Generic Clock Generator selected by GENDIV.ID.
    ///
    /// For Generator 0, all 16 bits of this field are used (bits [23:8]).
    /// For Generators 1–8, only the lower 8 bits are used (bits [15:8]).
    ///
    /// The effect of DIV depends on GENCTRL.DIVSEL for the selected generator:
    ///   - DIVSEL = 0: f_out = f_src / (DIV+1), or f_src if DIV = 0
    ///   - DIVSEL = 1: f_out = f_src / 2^(DIV+1)
    @inline(__always)
    static var divisionFactor: UInt32 {
        get {
            (generatorDivision >> 8) & 0xFFFF
        }
        set {
            generatorDivision = (generatorDivision & ~(0xFFFF << 8)) | ((newValue & 0xFFFF) << 8)
        }
    }
}
