//
//  SystemController.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/18/26.
//

@usableFromInline let SYSCTRL_BASE: UInt = 0x40000800   // SAMD21 datasheet §17.8

/// System Controller
///
/// The System Controller (SYSCTRL) manages all on-chip oscillators and voltage references
/// on the SAMD21, including:
///   - XOSC:     External Crystal / Clock-signal Oscillator (up to 32 MHz)
///   - XOSC32K:  32.768 kHz External Crystal Oscillator
///   - OSC32K:   32.768 kHz Internal Oscillator
///   - OSCULP32K: 32.768 kHz Ultra-Low-Power Internal Oscillator
///   - OSC8M:    8 MHz Internal RC Oscillator (with prescaler)
///   - DFLL48M:  48 MHz Digital Frequency Locked Loop
///   - BOD33:    3.3 V Brown-Out Detector
///   - VREG:     Voltage Regulator
///   - VREF:     Voltage References (temperature sensor, bandgap)
///   - FDPLL96M: 96 MHz Fractional Digital Phase-Locked Loop
///
/// Each oscillator must have its APB clock enabled in the PM (PowerManager.sysctrlClockEnable)
/// before its registers can be accessed.
///
/// Typical startup sequence:
///   1. Configure the desired oscillator (e.g. XOSC, DFLL48M).
///   2. Poll the matching `…Ready` flag in `powerAndClocksStatusRegister` (or wait for interrupt).
///   3. Route the oscillator to a GCLK generator via `GenericClockController`.
///
/// See SAMD21 datasheet Section 17.
struct SystemController {

    // MARK: - Supporting Enums

    // MARK: XOSC

    /// Crystal oscillator start-up time (XOSC.STARTUP).
    /// See SAMD21 datasheet Table 17-3.
    enum XOSCStartupTime: UInt32 {
        case us31     = 0x0
        case us61     = 0x1
        case us122    = 0x2
        case us244    = 0x3
        case us488    = 0x4
        case us977    = 0x5
        case us1953   = 0x6
        case us3906   = 0x7
        case us7813   = 0x8
        case us15625  = 0x9
        case us31250  = 0xA
        case us62500  = 0xB
        case us125000 = 0xC
        case us250000 = 0xD
        case us500000 = 0xE
        case us1000000 = 0xF
    }

    /// Crystal oscillator gain — sets the maximum supported input frequency (XOSC.GAIN).
    /// See SAMD21 datasheet Table 17-4.
    enum XOSCGain: UInt32 {
        case max2MHz  = 0   ///< Up to  2 MHz
        case max4MHz  = 1   ///< Up to  4 MHz
        case max8MHz  = 2   ///< Up to  8 MHz
        case max16MHz = 3   ///< Up to 16 MHz
        case max30MHz = 4   ///< Up to 30 MHz
    }

    // MARK: XOSC32K

    /// 32.768 kHz external crystal oscillator start-up time (XOSC32K.STARTUP).
    /// See SAMD21 datasheet Table 17-6.
    enum XOSC32KStartupTime: UInt32 {
        case us122      = 0   ///< 122 μs
        case us1068     = 1   ///< 1.068 ms
        case us62592    = 2   ///< 62.592 ms
        case us125092   = 3   ///< 125.092 ms
        case us500092   = 4   ///< 500.092 ms
        case us1000092  = 5   ///< 1000.092 ms
        case us2000092  = 6   ///< 2000.092 ms
        case us4000092  = 7   ///< 4000.092 ms
    }

    // MARK: OSC32K

    /// 32.768 kHz internal oscillator start-up time (OSC32K.STARTUP).
    /// See SAMD21 datasheet Table 17-8.
    enum OSC32KStartupTime: UInt32 {
        case cycles3   = 0   ///<  3 cycles (~92 μs at 32kHz)
        case cycles4   = 1   ///<  4 cycles
        case cycles6   = 2   ///<  6 cycles
        case cycles10  = 3   ///< 10 cycles
        case cycles18  = 4   ///< 18 cycles
        case cycles34  = 5   ///< 34 cycles
        case cycles66  = 6   ///< 66 cycles
        case cycles130 = 7   ///< 130 cycles
    }

    // MARK: OSC8M

    /// OSC8M output prescaler (OSC8M.PRESC).
    /// See SAMD21 datasheet Table 17-11.
    enum OSC8MPrescaler: UInt32 {
        case div1 = 0   ///< ÷1 — output = 8 MHz (factory trimmed)
        case div2 = 1   ///< ÷2 — output = 4 MHz
        case div4 = 2   ///< ÷4 — output = 2 MHz
        case div8 = 3   ///< ÷8 — output = 1 MHz
    }

    /// OSC8M calibration frequency range (OSC8M.FRANGE).
    /// See SAMD21 datasheet Table 17-12.
    enum OSC8MFrequencyRange: UInt32 {
        case range4To6MHz  = 0   ///<  4 to  6 MHz
        case range6To8MHz  = 1   ///<  6 to  8 MHz
        case range8To11MHz = 2   ///<  8 to 11 MHz
        case range11To15MHz = 3  ///< 11 to 15 MHz
    }

    // MARK: BOD33

    /// Brown-Out Detector 3.3 V action on detection (BOD33.ACTION).
    /// See SAMD21 datasheet Table 17-15.
    enum BOD33Action: UInt32 {
        case none      = 0   ///< No action; only the flag is set.
        case reset     = 1   ///< Generate a system reset.
        case interrupt = 2   ///< Generate an interrupt.
    }

    /// BOD33 sampling clock prescaler (BOD33.PSEL).
    /// See SAMD21 datasheet Table 17-16.
    enum BOD33Prescaler: UInt32 {
        case div1     = 0
        case div2     = 1
        case div4     = 2
        case div8     = 3
        case div16    = 4
        case div32    = 5
        case div64    = 6
        case div128   = 7
        case div256   = 8
        case div512   = 9
        case div1024  = 10
        case div2048  = 11
        case div4096  = 12
        case div8192  = 13
        case div16384 = 14
        case div32768 = 15
    }

    // MARK: FDPLL96M

    /// FDPLL96M proportional-integral filter selection (DPLLCTRLB.FILTER).
    /// See SAMD21 datasheet Table 17-22.
    enum DPLLFilter: UInt32 {
        case `default`    = 0   ///< Default filter mode.
        case lowBandwidth  = 1   ///< Low bandwidth filter.
        case highBandwidth = 2   ///< High bandwidth filter.
        case highDamping   = 3   ///< High damping filter.
    }

    /// FDPLL96M reference clock source (DPLLCTRLB.REFCLK).
    /// See SAMD21 datasheet Table 17-23.
    enum DPLLReferenceClockSource: UInt32 {
        case xosc32K = 0   ///< XOSC32K oscillator output.
        case xosc    = 1   ///< XOSC oscillator output.
        case gclk    = 2   ///< Generic Clock Generator 1 output.
    }

    /// FDPLL96M lock timeout (DPLLCTRLB.LTIME).
    /// See SAMD21 datasheet Table 17-24.
    enum DPLLLockTime: UInt32 {
        case noTimeout = 0   ///< No time-out; wait indefinitely for lock.
        case ms8       = 4   ///<  8 ms maximum lock time.
        case ms9       = 5   ///<  9 ms maximum lock time.
        case ms10      = 6   ///< 10 ms maximum lock time.
        case ms11      = 7   ///< 11 ms maximum lock time.
    }


    // MARK: - INTENCLR – Interrupt Enable Clear (Offset 0x00, 32-bit)
    //
    // INTENCLR, INTENSET, INTFLAG, and PCLKSR share the same bit layout:
    //   Bit  0: XOSCRDY      Bit  5: DFLLOOB    Bit 10: BOD33DET
    //   Bit  1: XOSC32KRDY   Bit  6: DFLLLCKF   Bit 11: B33SRDY
    //   Bit  2: OSC32KRDY    Bit  7: DFLLLCKC   Bit 15: DPLLLCKR
    //   Bit  3: OSC8MRDY     Bit  8: DFLLRCS    Bit 16: DPLLLCKF
    //   Bit  4: DFLLRDY      Bit  9: BOD33RDY   Bit 17: DPLLLTO
    //
    // INTENCLR and INTENSET are paired set/clear registers. Writing 1 to a bit in
    // INTENCLR clears the enable; writing 1 to a bit in INTENSET sets the enable.
    // Writing 0 to either has no effect, so no read-modify-write is needed.
    // INTFLAG bits are write-1-to-clear; writing 0 has no effect.

    /// INTENCLR – Interrupt Enable Clear Register
    /// See Section 17.8.1.
    ///
    /// Reading returns the current interrupt enable state for all interrupt sources.
    /// Writing '1' to a bit disables the corresponding interrupt; writing '0' has no effect.
    @inline(__always)
    static var interruptEnableClearRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x00)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x00, newValue)
        }
    }

    /// INTENSET – Interrupt Enable Set Register
    /// See Section 17.8.2.
    ///
    /// Reading returns the current interrupt enable state for all interrupt sources.
    /// Writing '1' to a bit enables the corresponding interrupt; writing '0' has no effect.
    @inline(__always)
    static var interruptEnableSetRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x04)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x04, newValue)
        }
    }

    /// INTFLAG – Interrupt Flag Status and Clear Register
    /// See Section 17.8.3.
    ///
    /// Bits are set by hardware when an event occurs. Write '1' to clear a flag.
    @inline(__always)
    static var interruptFlagRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x08)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x08, newValue)
        }
    }

    /// PCLKSR – Power and Clocks Status Register
    /// See Section 17.8.4.
    ///
    /// Read-only mirror of INTFLAG. Reflects the current ready/detected state of all
    /// oscillators and detectors without requiring an interrupt to be enabled.
    @inline(__always)
    static var powerAndClocksStatusRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x0C)
        }
    }

    // MARK: PCLKSR – individual status bits (read-only mirror of INTFLAG)

    /// XOSCRDY – XOSC Ready (non-latching status)
    @inline(__always)
    static var xoscReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 0)) != 0
    }

    /// XOSC32KRDY – XOSC32K Ready (non-latching status)
    @inline(__always)
    static var xosc32KReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 1)) != 0
    }

    /// OSC32KRDY – OSC32K Ready (non-latching status)
    @inline(__always)
    static var osc32KReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 2)) != 0
    }

    /// OSC8MRDY – OSC8M Ready (non-latching status)
    @inline(__always)
    static var osc8MReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 3)) != 0
    }

    /// DFLLRDY – DFLL48M Ready (non-latching status)
    @inline(__always)
    static var dfllReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 4)) != 0
    }

    /// DFLLOOB – DFLL48M Out Of Bounds (non-latching status)
    @inline(__always)
    static var dfllOutOfBoundsStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 5)) != 0
    }

    /// DFLLLCKF – DFLL48M Lock Fine (non-latching status)
    @inline(__always)
    static var dfllLockFineStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 6)) != 0
    }

    /// DFLLLCKC – DFLL48M Lock Coarse (non-latching status)
    @inline(__always)
    static var dfllLockCoarseStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 7)) != 0
    }

    /// DFLLRCS – DFLL48M Reference Clock Stopped (non-latching status)
    @inline(__always)
    static var dfllReferenceClockStoppedStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 8)) != 0
    }

    /// BOD33RDY – BOD33 Ready (non-latching status)
    @inline(__always)
    static var bod33ReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 9)) != 0
    }

    /// BOD33DET – BOD33 Detection (non-latching status)
    @inline(__always)
    static var bod33DetectedStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 10)) != 0
    }

    /// B33SRDY – BOD33 Synchronization Ready (non-latching status)
    @inline(__always)
    static var bod33SyncReadyStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 11)) != 0
    }

    /// DPLLLCKR – FDPLL96M Lock Rise (non-latching status)
    @inline(__always)
    static var dpllLockRiseStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 15)) != 0
    }

    /// DPLLLCKF – FDPLL96M Lock Fall (non-latching status)
    @inline(__always)
    static var dpllLockFallStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 16)) != 0
    }

    /// DPLLLTO – FDPLL96M Lock Timeout (non-latching status)
    @inline(__always)
    static var dpllLockTimeoutStatus: Bool {
        (powerAndClocksStatusRegister & (1 << 17)) != 0
    }

    // MARK: Interrupt enable helpers

    /// Helper that reads the enable state for a single bit from INTENCLR, and
    /// writes to INTENSET (enable) or INTENCLR (disable) as appropriate.
    @inline(__always)
    private static func interruptEnable(bit: UInt32) -> Bool {
        (interruptEnableClearRegister & (1 << bit)) != 0
    }

    @inline(__always)
    private static func setInterruptEnable(bit: UInt32, _ enabled: Bool) {
        if enabled {
            interruptEnableSetRegister = (1 << bit)
        } else {
            interruptEnableClearRegister = (1 << bit)
        }
    }

    /// XOSCRDY – XOSC Ready Interrupt Enable
    @inline(__always)
    static var xoscReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 0) }
        set { setInterruptEnable(bit: 0, newValue) }
    }

    /// XOSC32KRDY – XOSC32K Ready Interrupt Enable
    @inline(__always)
    static var xosc32KReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 1) }
        set { setInterruptEnable(bit: 1, newValue) }
    }

    /// OSC32KRDY – OSC32K Ready Interrupt Enable
    @inline(__always)
    static var osc32KReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 2) }
        set { setInterruptEnable(bit: 2, newValue) }
    }

    /// OSC8MRDY – OSC8M Ready Interrupt Enable
    @inline(__always)
    static var osc8MReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 3) }
        set { setInterruptEnable(bit: 3, newValue) }
    }

    /// DFLLRDY – DFLL48M Ready Interrupt Enable
    @inline(__always)
    static var dfllReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 4) }
        set { setInterruptEnable(bit: 4, newValue) }
    }

    /// DFLLOOB – DFLL48M Out Of Bounds Interrupt Enable
    @inline(__always)
    static var dfllOutOfBoundsInterruptEnable: Bool {
        get { interruptEnable(bit: 5) }
        set { setInterruptEnable(bit: 5, newValue) }
    }

    /// DFLLLCKF – DFLL48M Lock Fine Interrupt Enable
    @inline(__always)
    static var dfllLockFineInterruptEnable: Bool {
        get { interruptEnable(bit: 6) }
        set { setInterruptEnable(bit: 6, newValue) }
    }

    /// DFLLLCKC – DFLL48M Lock Coarse Interrupt Enable
    @inline(__always)
    static var dfllLockCoarseInterruptEnable: Bool {
        get { interruptEnable(bit: 7) }
        set { setInterruptEnable(bit: 7, newValue) }
    }

    /// DFLLRCS – DFLL48M Reference Clock Stopped Interrupt Enable
    @inline(__always)
    static var dfllReferenceClockStoppedInterruptEnable: Bool {
        get { interruptEnable(bit: 8) }
        set { setInterruptEnable(bit: 8, newValue) }
    }

    /// BOD33RDY – BOD33 Ready Interrupt Enable
    @inline(__always)
    static var bod33ReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 9) }
        set { setInterruptEnable(bit: 9, newValue) }
    }

    /// BOD33DET – BOD33 Detection Interrupt Enable
    @inline(__always)
    static var bod33DetectionInterruptEnable: Bool {
        get { interruptEnable(bit: 10) }
        set { setInterruptEnable(bit: 10, newValue) }
    }

    /// B33SRDY – BOD33 Synchronization Ready Interrupt Enable
    @inline(__always)
    static var bod33SyncReadyInterruptEnable: Bool {
        get { interruptEnable(bit: 11) }
        set { setInterruptEnable(bit: 11, newValue) }
    }

    /// DPLLLCKR – FDPLL96M Lock Rise Interrupt Enable
    @inline(__always)
    static var dpllLockRiseInterruptEnable: Bool {
        get { interruptEnable(bit: 15) }
        set { setInterruptEnable(bit: 15, newValue) }
    }

    /// DPLLLCKF – FDPLL96M Lock Fall Interrupt Enable
    @inline(__always)
    static var dpllLockFallInterruptEnable: Bool {
        get { interruptEnable(bit: 16) }
        set { setInterruptEnable(bit: 16, newValue) }
    }

    /// DPLLLTO – FDPLL96M Lock Timeout Interrupt Enable
    @inline(__always)
    static var dpllLockTimeoutInterruptEnable: Bool {
        get { interruptEnable(bit: 17) }
        set { setInterruptEnable(bit: 17, newValue) }
    }

    // MARK: INTFLAG status and clear helpers

    /// XOSCRDY – XOSC Ready flag. Write `true` to clear.
    @inline(__always)
    static var xoscReady: Bool {
        get { (interruptFlagRegister & (1 << 0)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 0) } }
    }

    /// XOSC32KRDY – XOSC32K Ready flag. Write `true` to clear.
    @inline(__always)
    static var xosc32KReady: Bool {
        get { (interruptFlagRegister & (1 << 1)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 1) } }
    }

    /// OSC32KRDY – OSC32K Ready flag. Write `true` to clear.
    @inline(__always)
    static var osc32KReady: Bool {
        get { (interruptFlagRegister & (1 << 2)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 2) } }
    }

    /// OSC8MRDY – OSC8M Ready flag. Write `true` to clear.
    @inline(__always)
    static var osc8MReady: Bool {
        get { (interruptFlagRegister & (1 << 3)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 3) } }
    }

    /// DFLLRDY – DFLL48M Ready flag. Write `true` to clear.
    @inline(__always)
    static var dfllReady: Bool {
        get { (interruptFlagRegister & (1 << 4)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 4) } }
    }

    /// DFLLOOB – DFLL48M Out Of Bounds flag. Write `true` to clear.
    @inline(__always)
    static var dfllOutOfBounds: Bool {
        get { (interruptFlagRegister & (1 << 5)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 5) } }
    }

    /// DFLLLCKF – DFLL48M Lock Fine flag. Write `true` to clear.
    @inline(__always)
    static var dfllLockFine: Bool {
        get { (interruptFlagRegister & (1 << 6)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 6) } }
    }

    /// DFLLLCKC – DFLL48M Lock Coarse flag. Write `true` to clear.
    @inline(__always)
    static var dfllLockCoarse: Bool {
        get { (interruptFlagRegister & (1 << 7)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 7) } }
    }

    /// DFLLRCS – DFLL48M Reference Clock Stopped flag. Write `true` to clear.
    @inline(__always)
    static var dfllReferenceClockStopped: Bool {
        get { (interruptFlagRegister & (1 << 8)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 8) } }
    }

    /// BOD33RDY – BOD33 Ready flag. Write `true` to clear.
    @inline(__always)
    static var bod33Ready: Bool {
        get { (interruptFlagRegister & (1 << 9)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 9) } }
    }

    /// BOD33DET – BOD33 Detection flag. Write `true` to clear.
    @inline(__always)
    static var bod33Detected: Bool {
        get { (interruptFlagRegister & (1 << 10)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 10) } }
    }

    /// B33SRDY – BOD33 Synchronization Ready flag. Write `true` to clear.
    @inline(__always)
    static var bod33SyncReady: Bool {
        get { (interruptFlagRegister & (1 << 11)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 11) } }
    }

    /// DPLLLCKR – FDPLL96M Lock Rise flag. Write `true` to clear.
    @inline(__always)
    static var dpllLockRise: Bool {
        get { (interruptFlagRegister & (1 << 15)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 15) } }
    }

    /// DPLLLCKF – FDPLL96M Lock Fall flag. Write `true` to clear.
    @inline(__always)
    static var dpllLockFall: Bool {
        get { (interruptFlagRegister & (1 << 16)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 16) } }
    }

    /// DPLLLTO – FDPLL96M Lock Timeout flag. Write `true` to clear.
    @inline(__always)
    static var dpllLockTimeout: Bool {
        get { (interruptFlagRegister & (1 << 17)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 17) } }
    }


    // MARK: - XOSC – External Multipurpose Crystal Oscillator Control (Offset 0x10, 16-bit)

    /// XOSC – External Multipurpose Crystal Oscillator Control Register
    /// See Section 17.8.5.
    ///
    /// Controls the external crystal oscillator or external clock input on the XIN/XOUT pins.
    /// Read/written as bits [15:0] of a 32-bit word; bits [31:16] are reserved and preserved.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// | 15:12 | STARTUP | R/W | Start-Up Time. See XOSCStartupTime enum.    |
    /// -----------------------------------------------------------------------
    /// |  11   | AMPGC   | R/W | Automatic Amplitude Gain Control Enable.    |
    /// -----------------------------------------------------------------------
    /// | 10:8  | GAIN    | R/W | Oscillator Gain. See XOSCGain enum.         |
    /// -----------------------------------------------------------------------
    /// |   7   | ONDEMAND| R/W | On Demand Control (gated unless requested). |
    /// -----------------------------------------------------------------------
    /// |   6   | RUNSTDBY| R/W | Run in Standby.                             |
    /// -----------------------------------------------------------------------
    /// |   2   | XTALEN  | R/W | '1' = crystal oscillator; '0' = clock input.|
    /// -----------------------------------------------------------------------
    /// |   1   | ENABLE  | R/W | Oscillator Enable.                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var xoscRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x10) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x10)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x10, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// XOSC.ENABLE – External Oscillator Enable
    @inline(__always)
    static var xoscEnable: Bool {
        get { (xoscRegister & (1 << 1)) != 0 }
        set {
            xoscRegister = newValue
                ? (xoscRegister | (1 << 1))
                : (xoscRegister & ~(1 << 1))
        }
    }

    /// XOSC.XTALEN – Crystal Oscillator Enable
    ///
    /// '1' selects crystal oscillator mode (requires XOUT pin for feedback).
    /// '0' selects external clock signal input mode (single-pin, XOUT unused).
    @inline(__always)
    static var xoscCrystalEnable: Bool {
        get { (xoscRegister & (1 << 2)) != 0 }
        set {
            xoscRegister = newValue
                ? (xoscRegister | (1 << 2))
                : (xoscRegister & ~(1 << 2))
        }
    }

    /// XOSC.RUNSTDBY – Run in Standby
    @inline(__always)
    static var xoscRunInStandby: Bool {
        get { (xoscRegister & (1 << 6)) != 0 }
        set {
            xoscRegister = newValue
                ? (xoscRegister | (1 << 6))
                : (xoscRegister & ~(1 << 6))
        }
    }

    /// XOSC.ONDEMAND – On Demand Control
    ///
    /// When set, the oscillator is only enabled when requested by a peripheral.
    /// When clear, the oscillator runs whenever ENABLE is set.
    @inline(__always)
    static var xoscOnDemand: Bool {
        get { (xoscRegister & (1 << 7)) != 0 }
        set {
            xoscRegister = newValue
                ? (xoscRegister | (1 << 7))
                : (xoscRegister & ~(1 << 7))
        }
    }

    /// XOSC.GAIN – Oscillator Gain
    ///
    /// Sets the maximum supported oscillator frequency. Must be chosen to match
    /// the crystal or external clock frequency being used.
    @inline(__always)
    static var xoscGain: XOSCGain {
        get {
            let gain = (xoscRegister >> 8) & 0x07
            return XOSCGain(rawValue: gain) ?? .max2MHz
        }
        set {
            xoscRegister = (xoscRegister & ~(0x07 << 8)) | ((newValue.rawValue & 0x07) << 8)
        }
    }

    /// XOSC.AMPGC – Automatic Amplitude Gain Control
    ///
    /// When set, the oscillator amplitude is automatically controlled to minimise
    /// power consumption. When clear, GAIN sets a fixed amplitude.
    @inline(__always)
    static var xoscAutoAmplitudeControl: Bool {
        get { (xoscRegister & (1 << 11)) != 0 }
        set {
            xoscRegister = newValue
                ? (xoscRegister | (1 << 11))
                : (xoscRegister & ~(1 << 11))
        }
    }

    /// XOSC.STARTUP – Oscillator Start-Up Time
    ///
    /// The oscillator output is not guaranteed stable until this period has elapsed
    /// after ENABLE is set. Poll `xoscReady` in PCLKSR before using the clock.
    @inline(__always)
    static var xoscStartupTime: XOSCStartupTime {
        get {
            let t = (xoscRegister >> 12) & 0x0F
            return XOSCStartupTime(rawValue: t) ?? .us31
        }
        set {
            xoscRegister = (xoscRegister & ~(0x0F << 12)) | ((newValue.rawValue & 0x0F) << 12)
        }
    }


    // MARK: - XOSC32K – 32.768 kHz External Crystal Oscillator Control (Offset 0x14, 16-bit)

    /// XOSC32K – 32.768 kHz External Crystal Oscillator Control Register
    /// See Section 17.8.6.
    ///
    /// Read/written as bits [15:0] of a 32-bit word at SYSCTRL_BASE + 0x14.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// |  12   | WRTLOCK | R/W | Write Lock — locks register until reset.    |
    /// -----------------------------------------------------------------------
    /// | 10:8  | STARTUP | R/W | Start-Up Time. See XOSC32KStartupTime enum. |
    /// -----------------------------------------------------------------------
    /// |   7   | ONDEMAND| R/W | On Demand Control.                          |
    /// -----------------------------------------------------------------------
    /// |   6   | RUNSTDBY| R/W | Run in Standby.                             |
    /// -----------------------------------------------------------------------
    /// |   5   | AAMPEN  | R/W | Automatic Amplitude Control Enable.         |
    /// -----------------------------------------------------------------------
    /// |   4   | EN1K    | R/W | 1 kHz Output Enable.                        |
    /// -----------------------------------------------------------------------
    /// |   3   | EN32K   | R/W | 32.768 kHz Output Enable.                   |
    /// -----------------------------------------------------------------------
    /// |   2   | XTALEN  | R/W | '1' = crystal; '0' = external clock input.  |
    /// -----------------------------------------------------------------------
    /// |   1   | ENABLE  | R/W | Oscillator Enable.                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var xosc32KRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x14) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x14)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x14, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// XOSC32K.ENABLE
    @inline(__always)
    static var xosc32KEnable: Bool {
        get { (xosc32KRegister & (1 << 1)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 1))
                : (xosc32KRegister & ~(1 << 1))
        }
    }

    /// XOSC32K.XTALEN – Crystal Oscillator Enable
    @inline(__always)
    static var xosc32KCrystalEnable: Bool {
        get { (xosc32KRegister & (1 << 2)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 2))
                : (xosc32KRegister & ~(1 << 2))
        }
    }

    /// XOSC32K.EN32K – 32.768 kHz Clock Output Enable
    @inline(__always)
    static var xosc32K32KOutputEnable: Bool {
        get { (xosc32KRegister & (1 << 3)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 3))
                : (xosc32KRegister & ~(1 << 3))
        }
    }

    /// XOSC32K.EN1K – 1 kHz Clock Output Enable
    @inline(__always)
    static var xosc32K1KOutputEnable: Bool {
        get { (xosc32KRegister & (1 << 4)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 4))
                : (xosc32KRegister & ~(1 << 4))
        }
    }

    /// XOSC32K.AAMPEN – Automatic Amplitude Control Enable
    @inline(__always)
    static var xosc32KAutoAmplitudeEnable: Bool {
        get { (xosc32KRegister & (1 << 5)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 5))
                : (xosc32KRegister & ~(1 << 5))
        }
    }

    /// XOSC32K.RUNSTDBY
    @inline(__always)
    static var xosc32KRunInStandby: Bool {
        get { (xosc32KRegister & (1 << 6)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 6))
                : (xosc32KRegister & ~(1 << 6))
        }
    }

    /// XOSC32K.ONDEMAND
    @inline(__always)
    static var xosc32KOnDemand: Bool {
        get { (xosc32KRegister & (1 << 7)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 7))
                : (xosc32KRegister & ~(1 << 7))
        }
    }

    /// XOSC32K.STARTUP – Start-Up Time
    @inline(__always)
    static var xosc32KStartupTime: XOSC32KStartupTime {
        get {
            let t = (xosc32KRegister >> 8) & 0x07
            return XOSC32KStartupTime(rawValue: t) ?? .us122
        }
        set {
            xosc32KRegister = (xosc32KRegister & ~(0x07 << 8)) | ((newValue.rawValue & 0x07) << 8)
        }
    }

    /// XOSC32K.WRTLOCK – Write Lock
    ///
    /// When set, writes to XOSC32K and the corresponding GCLK generator registers are
    /// ignored until the next system reset. Set this after finalising the 32K configuration.
    @inline(__always)
    static var xosc32KWriteLock: Bool {
        get { (xosc32KRegister & (1 << 12)) != 0 }
        set {
            xosc32KRegister = newValue
                ? (xosc32KRegister | (1 << 12))
                : (xosc32KRegister & ~(1 << 12))
        }
    }


    // MARK: - OSC32K – 32.768 kHz Internal Oscillator Control (Offset 0x18, 32-bit)

    /// OSC32K – 32.768 kHz Internal Oscillator Control Register
    /// See Section 17.8.7.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// | 22:16 | CALIB   | R/W | Calibration value (7 bits).                 |
    /// -----------------------------------------------------------------------
    /// |  12   | WRTLOCK | R/W | Write Lock — locks register until reset.    |
    /// -----------------------------------------------------------------------
    /// | 10:8  | STARTUP | R/W | Start-Up Time. See OSC32KStartupTime enum.  |
    /// -----------------------------------------------------------------------
    /// |   7   | ONDEMAND| R/W | On Demand Control.                          |
    /// -----------------------------------------------------------------------
    /// |   6   | RUNSTDBY| R/W | Run in Standby.                             |
    /// -----------------------------------------------------------------------
    /// |   3   | EN1K    | R/W | 1 kHz Output Enable.                        |
    /// -----------------------------------------------------------------------
    /// |   2   | EN32K   | R/W | 32.768 kHz Output Enable.                   |
    /// -----------------------------------------------------------------------
    /// |   1   | ENABLE  | R/W | Oscillator Enable.                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var osc32KRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x18)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x18, newValue)
        }
    }

    /// OSC32K.ENABLE
    @inline(__always)
    static var osc32KEnable: Bool {
        get { (osc32KRegister & (1 << 1)) != 0 }
        set {
            osc32KRegister = newValue
                ? (osc32KRegister | (1 << 1))
                : (osc32KRegister & ~(1 << 1))
        }
    }

    /// OSC32K.EN32K – 32.768 kHz Output Enable
    @inline(__always)
    static var osc32K32KOutputEnable: Bool {
        get { (osc32KRegister & (1 << 2)) != 0 }
        set {
            osc32KRegister = newValue
                ? (osc32KRegister | (1 << 2))
                : (osc32KRegister & ~(1 << 2))
        }
    }

    /// OSC32K.EN1K – 1 kHz Output Enable
    @inline(__always)
    static var osc32K1KOutputEnable: Bool {
        get { (osc32KRegister & (1 << 3)) != 0 }
        set {
            osc32KRegister = newValue
                ? (osc32KRegister | (1 << 3))
                : (osc32KRegister & ~(1 << 3))
        }
    }

    /// OSC32K.RUNSTDBY
    @inline(__always)
    static var osc32KRunInStandby: Bool {
        get { (osc32KRegister & (1 << 6)) != 0 }
        set {
            osc32KRegister = newValue
                ? (osc32KRegister | (1 << 6))
                : (osc32KRegister & ~(1 << 6))
        }
    }

    /// OSC32K.ONDEMAND
    @inline(__always)
    static var osc32KOnDemand: Bool {
        get { (osc32KRegister & (1 << 7)) != 0 }
        set {
            osc32KRegister = newValue
                ? (osc32KRegister | (1 << 7))
                : (osc32KRegister & ~(1 << 7))
        }
    }

    /// OSC32K.STARTUP – Start-Up Time
    @inline(__always)
    static var osc32KStartupTime: OSC32KStartupTime {
        get {
            let t = (osc32KRegister >> 8) & 0x07
            return OSC32KStartupTime(rawValue: t) ?? .cycles3
        }
        set {
            osc32KRegister = (osc32KRegister & ~(0x07 << 8)) | ((newValue.rawValue & 0x07) << 8)
        }
    }

    /// OSC32K.WRTLOCK – Write Lock
    @inline(__always)
    static var osc32KWriteLock: Bool {
        get { (osc32KRegister & (1 << 12)) != 0 }
        set {
            osc32KRegister = newValue
                ? (osc32KRegister | (1 << 12))
                : (osc32KRegister & ~(1 << 12))
        }
    }

    /// OSC32K.CALIB – Calibration Value (7 bits, bits [22:16])
    ///
    /// Factory calibration is loaded automatically from NVM on reset. Write only if
    /// fine-tuning the oscillator frequency against an external reference.
    @inline(__always)
    static var osc32KCalibration: UInt32 {
        get {
            (osc32KRegister >> 16) & 0x7F
        }
        set {
            osc32KRegister = (osc32KRegister & ~(0x7F << 16)) | ((newValue & 0x7F) << 16)
        }
    }


    // MARK: - OSCULP32K – 32.768 kHz Ultra Low Power Oscillator Control (Offset 0x1C, 8-bit)

    /// OSCULP32K – Ultra Low Power 32.768 kHz Oscillator Control Register
    /// See Section 17.8.8.
    ///
    /// The OSCULP32K oscillator cannot be disabled — it is always-on and is the backup
    /// clock source used by the Clock Failure Detector. Only calibration and write-lock
    /// can be configured.
    ///
    /// Read/written as bits [7:0] of a 32-bit word; upper bytes are reserved.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  7   | WRTLOCK | R/W | Write Lock — locks register until reset.      |
    /// -----------------------------------------------------------------------
    /// | 4:0  | CALIB   | R/W | Calibration value (5 bits).                   |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var oscULP32KRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x1C) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x1C)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x1C, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// OSCULP32K.CALIB – Calibration Value (5 bits)
    @inline(__always)
    static var oscULP32KCalibration: UInt32 {
        get { oscULP32KRegister & 0x1F }
        set { oscULP32KRegister = (oscULP32KRegister & ~0x1F) | (newValue & 0x1F) }
    }

    /// OSCULP32K.WRTLOCK – Write Lock
    @inline(__always)
    static var oscULP32KWriteLock: Bool {
        get { (oscULP32KRegister & (1 << 7)) != 0 }
        set {
            oscULP32KRegister = newValue
                ? (oscULP32KRegister | (1 << 7))
                : (oscULP32KRegister & ~(1 << 7))
        }
    }


    // MARK: - OSC8M – 8 MHz Internal Oscillator Control (Offset 0x20, 32-bit)

    /// OSC8M – 8 MHz Internal RC Oscillator Control Register
    /// See Section 17.8.9.
    ///
    /// The OSC8M is enabled by default after reset with PRESC = ÷8 (1 MHz output),
    /// and is the default clock source for the CPU until firmware reconfigures it.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// | 31:30 | FRANGE  |  R  | Frequency Range (factory set). See enum.    |
    /// -----------------------------------------------------------------------
    /// | 27:16 | CALIB   | R/W | Calibration value (12 bits).                |
    /// -----------------------------------------------------------------------
    /// |  9:8  | PRESC   | R/W | Output Prescaler. See OSC8MPrescaler enum.  |
    /// -----------------------------------------------------------------------
    /// |   7   | ONDEMAND| R/W | On Demand Control.                          |
    /// -----------------------------------------------------------------------
    /// |   6   | RUNSTDBY| R/W | Run in Standby.                             |
    /// -----------------------------------------------------------------------
    /// |   1   | ENABLE  | R/W | Oscillator Enable.                          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var osc8MRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x20)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x20, newValue)
        }
    }

    /// OSC8M.ENABLE
    @inline(__always)
    static var osc8MEnable: Bool {
        get { (osc8MRegister & (1 << 1)) != 0 }
        set {
            osc8MRegister = newValue
                ? (osc8MRegister | (1 << 1))
                : (osc8MRegister & ~(1 << 1))
        }
    }

    /// OSC8M.RUNSTDBY
    @inline(__always)
    static var osc8MRunInStandby: Bool {
        get { (osc8MRegister & (1 << 6)) != 0 }
        set {
            osc8MRegister = newValue
                ? (osc8MRegister | (1 << 6))
                : (osc8MRegister & ~(1 << 6))
        }
    }

    /// OSC8M.ONDEMAND
    @inline(__always)
    static var osc8MOnDemand: Bool {
        get { (osc8MRegister & (1 << 7)) != 0 }
        set {
            osc8MRegister = newValue
                ? (osc8MRegister | (1 << 7))
                : (osc8MRegister & ~(1 << 7))
        }
    }

    /// OSC8M.PRESC – Output Prescaler
    ///
    /// Divides the 8 MHz oscillator output before it feeds the clock system.
    /// After reset the default is div8 (1 MHz). Set to div1 for the full 8 MHz output.
    @inline(__always)
    static var osc8MPrescaler: OSC8MPrescaler {
        get {
            let p = (osc8MRegister >> 8) & 0x03
            return OSC8MPrescaler(rawValue: p) ?? .div1
        }
        set {
            osc8MRegister = (osc8MRegister & ~(0x03 << 8)) | ((newValue.rawValue & 0x03) << 8)
        }
    }

    /// OSC8M.CALIB – Calibration Value (12 bits, bits [27:16])
    ///
    /// Factory calibration is loaded automatically from NVM on reset.
    @inline(__always)
    static var osc8MCalibration: UInt32 {
        get {
            (osc8MRegister >> 16) & 0xFFF
        }
        set {
            osc8MRegister = (osc8MRegister & ~(0xFFF << 16)) | ((newValue & 0xFFF) << 16)
        }
    }

    /// OSC8M.FRANGE – Frequency Range (read-only)
    ///
    /// Set at the factory to indicate the calibrated frequency range of this oscillator.
    /// Must not be written.
    @inline(__always)
    static var osc8MFrequencyRange: OSC8MFrequencyRange {
        get {
            let r = (osc8MRegister >> 30) & 0x03
            return OSC8MFrequencyRange(rawValue: r) ?? .range8To11MHz
        }
    }


    // MARK: - DFLLCTRL – DFLL48M Control Register (Offset 0x24, 16-bit)

    /// DFLLCTRL – Digital Frequency Locked Loop 48 MHz Control Register
    /// See Section 17.8.10.
    ///
    /// Configures the DFLL48M operating mode and options. The DFLL can run in
    /// open-loop mode (free-running at approximately 48 MHz) or closed-loop mode
    /// (phase/frequency locked to a reference generic clock).
    ///
    /// Read/written as bits [15:0] of a 32-bit word at SYSCTRL_BASE + 0x24.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name     | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 11  | WAITLOCK | R/W | Wait for DFLL lock before outputting clock.  |
    /// -----------------------------------------------------------------------
    /// | 10  | BPLCKC   | R/W | Bypass Coarse Lock.                          |
    /// -----------------------------------------------------------------------
    /// |  9  | QLDIS    | R/W | Quick Lock Disable.                          |
    /// -----------------------------------------------------------------------
    /// |  8  | CCDIS    | R/W | Chill Cycle Disable.                         |
    /// -----------------------------------------------------------------------
    /// |  7  | ONDEMAND | R/W | On Demand Control.                           |
    /// -----------------------------------------------------------------------
    /// |  6  | RUNSTDBY | R/W | Run in Standby.                              |
    /// -----------------------------------------------------------------------
    /// |  5  | USBCRM   | R/W | USB Clock Recovery Mode.                     |
    /// -----------------------------------------------------------------------
    /// |  4  | LLAW     | R/W | Lose Lock After Wake.                        |
    /// -----------------------------------------------------------------------
    /// |  3  | STABLE   | R/W | Stable DFLL Frequency.                       |
    /// -----------------------------------------------------------------------
    /// |  2  | MODE     | R/W | '0' = Open Loop, '1' = Closed Loop.          |
    /// -----------------------------------------------------------------------
    /// |  1  | ENABLE   | R/W | DFLL Enable.                                 |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dfllControlRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x24) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x24)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x24, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// DFLLCTRL.ENABLE
    @inline(__always)
    static var dfllEnable: Bool {
        get { (dfllControlRegister & (1 << 1)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 1))
                : (dfllControlRegister & ~(1 << 1))
        }
    }

    /// DFLLCTRL.MODE – Operating Mode
    ///
    /// '0' = Open-loop (free-running, approximate 48 MHz).
    /// '1' = Closed-loop (locked to reference generic clock).
    @inline(__always)
    static var dfllClosedLoopMode: Bool {
        get { (dfllControlRegister & (1 << 2)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 2))
                : (dfllControlRegister & ~(1 << 2))
        }
    }

    /// DFLLCTRL.STABLE – Stable DFLL Frequency
    ///
    /// When set, the FINE value in DFLLVAL is not updated after the DFLL locks, keeping
    /// the frequency stable at the cost of slightly reduced accuracy.
    @inline(__always)
    static var dfllStableFrequency: Bool {
        get { (dfllControlRegister & (1 << 3)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 3))
                : (dfllControlRegister & ~(1 << 3))
        }
    }

    /// DFLLCTRL.LLAW – Lose Lock After Wake
    ///
    /// When set, the DFLL is considered unlocked after waking from sleep and must
    /// re-acquire lock before the `dfllReady` flag is set again.
    @inline(__always)
    static var dfllLoseLockAfterWake: Bool {
        get { (dfllControlRegister & (1 << 4)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 4))
                : (dfllControlRegister & ~(1 << 4))
        }
    }

    /// DFLLCTRL.USBCRM – USB Clock Recovery Mode
    ///
    /// When set, the DFLL uses the USB SOF (Start-Of-Frame) signal as the reference
    /// instead of a generic clock. Enables precise 48 MHz generation from USB.
    @inline(__always)
    static var dfllUSBClockRecoveryMode: Bool {
        get { (dfllControlRegister & (1 << 5)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 5))
                : (dfllControlRegister & ~(1 << 5))
        }
    }

    /// DFLLCTRL.RUNSTDBY
    @inline(__always)
    static var dfllRunInStandby: Bool {
        get { (dfllControlRegister & (1 << 6)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 6))
                : (dfllControlRegister & ~(1 << 6))
        }
    }

    /// DFLLCTRL.ONDEMAND
    @inline(__always)
    static var dfllOnDemand: Bool {
        get { (dfllControlRegister & (1 << 7)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 7))
                : (dfllControlRegister & ~(1 << 7))
        }
    }

    /// DFLLCTRL.CCDIS – Chill Cycle Disable
    ///
    /// The chill cycle is a pause in the locking sequence that improves stability.
    /// Disable it to shorten lock acquisition time at the cost of potential overshoot.
    @inline(__always)
    static var dfllChillCycleDisable: Bool {
        get { (dfllControlRegister & (1 << 8)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 8))
                : (dfllControlRegister & ~(1 << 8))
        }
    }

    /// DFLLCTRL.QLDIS – Quick Lock Disable
    ///
    /// When set, the quick-lock feature is disabled and the DFLL uses only the
    /// standard lock algorithm, which is more accurate but slower.
    @inline(__always)
    static var dfllQuickLockDisable: Bool {
        get { (dfllControlRegister & (1 << 9)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 9))
                : (dfllControlRegister & ~(1 << 9))
        }
    }

    /// DFLLCTRL.BPLCKC – Bypass Coarse Lock
    ///
    /// When set, the coarse lock step is bypassed and only the fine lock is performed.
    @inline(__always)
    static var dfllBypassCoarseLock: Bool {
        get { (dfllControlRegister & (1 << 10)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 10))
                : (dfllControlRegister & ~(1 << 10))
        }
    }

    /// DFLLCTRL.WAITLOCK – Wait for Lock Before Output
    ///
    /// When set, the DFLL output clock is not released until the DFLL has locked.
    /// When clear, the output is available immediately (potentially at wrong frequency).
    @inline(__always)
    static var dfllWaitLock: Bool {
        get { (dfllControlRegister & (1 << 11)) != 0 }
        set {
            dfllControlRegister = newValue
                ? (dfllControlRegister | (1 << 11))
                : (dfllControlRegister & ~(1 << 11))
        }
    }


    // MARK: - DFLLVAL – DFLL48M Value Register (Offset 0x28, 32-bit)

    /// DFLLVAL – DFLL48M Value Register
    /// See Section 17.8.11.
    ///
    /// Contains the FINE and COARSE tuning values used by the DFLL. In open-loop mode
    /// these are written directly. In closed-loop mode they are updated by hardware;
    /// trigger a read by setting DFLLSYNC.READREQ first.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name   | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 25:16 | DIFF   |  R  | Multiplication Ratio Difference (signed).    |
    /// -----------------------------------------------------------------------
    /// | 15:10 | COARSE | R/W | Coarse tuning value (6 bits).                |
    /// -----------------------------------------------------------------------
    /// |  9:0  | FINE   | R/W | Fine tuning value (10 bits).                 |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dfllValueRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x28)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x28, newValue)
        }
    }

    /// DFLLVAL.FINE – Fine Tuning Value (bits [9:0])
    @inline(__always)
    static var dfllFineValue: UInt32 {
        get { dfllValueRegister & 0x3FF }
        set { dfllValueRegister = (dfllValueRegister & ~0x3FF) | (newValue & 0x3FF) }
    }

    /// DFLLVAL.COARSE – Coarse Tuning Value (bits [15:10])
    @inline(__always)
    static var dfllCoarseValue: UInt32 {
        get { (dfllValueRegister >> 10) & 0x3F }
        set { dfllValueRegister = (dfllValueRegister & ~(0x3F << 10)) | ((newValue & 0x3F) << 10) }
    }

    /// DFLLVAL.DIFF – Multiplication Ratio Difference (bits [25:16], read-only)
    ///
    /// In closed-loop mode, reports the signed difference between the target and actual
    /// multiplication ratios. Used to monitor lock accuracy.
    @inline(__always)
    static var dfllDiff: Int32 {
        get {
            let raw = (dfllValueRegister >> 16) & 0x3FF
            // Sign-extend from 10 bits
            return (raw & 0x200) != 0
                ? Int32(bitPattern: raw | 0xFFFFFC00)
                : Int32(bitPattern: raw)
        }
    }


    // MARK: - DFLLMUL – DFLL48M Multiplier Register (Offset 0x2C, 32-bit)

    /// DFLLMUL – DFLL48M Multiplier Register
    /// See Section 17.8.12.
    ///
    /// Sets the multiplication factor and maximum step sizes used in closed-loop mode.
    /// Write this register before enabling closed-loop mode.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name  | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// | 31:26 | CSTEP | R/W | Maximum Coarse Step Size (6 bits).            |
    /// -----------------------------------------------------------------------
    /// | 25:16 | FSTEP | R/W | Maximum Fine Step Size (10 bits).             |
    /// -----------------------------------------------------------------------
    /// | 15:0  | MUL   | R/W | DFLL Multiply Factor.                         |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dfllMultiplierRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x2C)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x2C, newValue)
        }
    }

    /// DFLLMUL.MUL – Multiply Factor (bits [15:0])
    ///
    /// In closed-loop mode: f_DFLL = f_ref × MUL. For 48 MHz from a 32.768 kHz reference:
    /// MUL = 48_000_000 / 32_768 = 1465.
    @inline(__always)
    static var dfllMultiplyFactor: UInt32 {
        get { dfllMultiplierRegister & 0xFFFF }
        set { dfllMultiplierRegister = (dfllMultiplierRegister & ~0xFFFF) | (newValue & 0xFFFF) }
    }

    /// DFLLMUL.FSTEP – Maximum Fine Step Size (bits [25:16])
    ///
    /// Limits how much the FINE value can change per reference clock cycle.
    /// Smaller values improve stability; larger values speed up acquisition.
    @inline(__always)
    static var dfllFineStepSize: UInt32 {
        get { (dfllMultiplierRegister >> 16) & 0x3FF }
        set { dfllMultiplierRegister = (dfllMultiplierRegister & ~(0x3FF << 16)) | ((newValue & 0x3FF) << 16) }
    }

    /// DFLLMUL.CSTEP – Maximum Coarse Step Size (bits [31:26])
    ///
    /// Limits how much the COARSE value can change per reference clock cycle.
    @inline(__always)
    static var dfllCoarseStepSize: UInt32 {
        get { (dfllMultiplierRegister >> 26) & 0x3F }
        set { dfllMultiplierRegister = (dfllMultiplierRegister & ~(0x3F << 26)) | ((newValue & 0x3F) << 26) }
    }


    // MARK: - DFLLSYNC – DFLL48M Synchronization Register (Offset 0x30, 8-bit)

    /// DFLLSYNC – DFLL48M Synchronization Register
    /// See Section 17.8.13.
    ///
    /// Writing '1' to READREQ triggers a synchronisation read of DFLLVAL in closed-loop
    /// mode. The bit is cleared automatically when the read is complete.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  1  | READREQ | R/W | '1' triggers a DFLLVAL register read request. |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dfllSyncRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x30) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x30)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x30, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// DFLLSYNC.READREQ – Read Request
    ///
    /// Set to '1' to trigger a synchronised read of DFLLVAL. Hardware clears the bit
    /// when the synchronisation is complete and DFLLVAL holds valid data.
    @inline(__always)
    static var dfllReadRequest: Bool {
        get { (dfllSyncRegister & (1 << 1)) != 0 }
        set {
            dfllSyncRegister = newValue
                ? (dfllSyncRegister | (1 << 1))
                : (dfllSyncRegister & ~(1 << 1))
        }
    }


    // MARK: - BOD33 – 3.3 V Brown-Out Detector Control (Offset 0x34, 32-bit)

    /// BOD33 – Brown-Out Detector 3.3 V Control Register
    /// See Section 17.8.14.
    ///
    /// Monitors the VDD supply voltage and triggers an action when it falls below
    /// a programmable threshold.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// | 19:16 | PSEL    | R/W | Prescaler select. See BOD33Prescaler enum.  |
    /// -----------------------------------------------------------------------
    /// | 13:8  | LEVEL   | R/W | Detection level (6 bits). Higher = higher V.|
    /// -----------------------------------------------------------------------
    /// |   6   | RUNSTDBY| R/W | Run in Standby.                             |
    /// -----------------------------------------------------------------------
    /// |  5:4  | ACTION  | R/W | Action on detection. See BOD33Action enum.  |
    /// -----------------------------------------------------------------------
    /// |   2   | HYST    | R/W | Hysteresis Enable.                          |
    /// -----------------------------------------------------------------------
    /// |   1   | ENABLE  | R/W | BOD33 Enable.                               |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var bod33Register: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x34)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x34, newValue)
        }
    }

    /// BOD33.ENABLE
    @inline(__always)
    static var bod33Enable: Bool {
        get { (bod33Register & (1 << 1)) != 0 }
        set {
            bod33Register = newValue
                ? (bod33Register | (1 << 1))
                : (bod33Register & ~(1 << 1))
        }
    }

    /// BOD33.HYST – Hysteresis Enable
    ///
    /// When set, a hysteresis band is applied around the detection threshold to prevent
    /// rapid toggling when the supply voltage is near the threshold.
    @inline(__always)
    static var bod33HysteresisEnable: Bool {
        get { (bod33Register & (1 << 2)) != 0 }
        set {
            bod33Register = newValue
                ? (bod33Register | (1 << 2))
                : (bod33Register & ~(1 << 2))
        }
    }

    /// BOD33.ACTION – Action on Detection (bits [5:4])
    @inline(__always)
    static var bod33Action: BOD33Action {
        get {
            let a = (bod33Register >> 4) & 0x03
            return BOD33Action(rawValue: a) ?? .none
        }
        set {
            bod33Register = (bod33Register & ~(0x03 << 4)) | ((newValue.rawValue & 0x03) << 4)
        }
    }

    /// BOD33.RUNSTDBY
    @inline(__always)
    static var bod33RunInStandby: Bool {
        get { (bod33Register & (1 << 6)) != 0 }
        set {
            bod33Register = newValue
                ? (bod33Register | (1 << 6))
                : (bod33Register & ~(1 << 6))
        }
    }

    /// BOD33.LEVEL – Detection Level (bits [13:8], 6 bits)
    ///
    /// Sets the voltage threshold. A higher value corresponds to a higher trigger voltage.
    /// Consult Table 37-22 in the SAMD21 datasheet for the voltage-to-code mapping.
    @inline(__always)
    static var bod33Level: UInt32 {
        get { (bod33Register >> 8) & 0x3F }
        set { bod33Register = (bod33Register & ~(0x3F << 8)) | ((newValue & 0x3F) << 8) }
    }

    /// BOD33.PSEL – Prescaler Select (bits [19:16])
    ///
    /// Sets the prescaler for the BOD33 sampling clock. A higher prescaler reduces
    /// power consumption at the cost of slower detection response time.
    @inline(__always)
    static var bod33Prescaler: BOD33Prescaler {
        get {
            let p = (bod33Register >> 16) & 0x0F
            return BOD33Prescaler(rawValue: p) ?? .div1
        }
        set {
            bod33Register = (bod33Register & ~(0x0F << 16)) | ((newValue.rawValue & 0x0F) << 16)
        }
    }


    // MARK: - VREG – Voltage Regulator System Control (Offset 0x3C, 16-bit)

    /// VREG – Voltage Regulator System Control Register
    /// See Section 17.8.15.
    ///
    /// Controls the on-chip voltage regulator behavior in Standby sleep.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  6  | RUNSTDBY| R/W | '1' keeps regulator in normal mode in Standby.|
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var vregRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x3C) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x3C)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x3C, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// VREG.RUNSTDBY – Regulator Run in Standby
    ///
    /// When set, the voltage regulator remains in normal (full-power) mode during
    /// Standby sleep. When clear, it switches to a low-power mode in Standby.
    @inline(__always)
    static var vregRunInStandby: Bool {
        get { (vregRegister & (1 << 6)) != 0 }
        set {
            vregRegister = newValue
                ? (vregRegister | (1 << 6))
                : (vregRegister & ~(1 << 6))
        }
    }


    // MARK: - VREF – Voltage References System Control (Offset 0x40, 32-bit)

    /// VREF – Voltage References System Control Register
    /// See Section 17.8.16.
    ///
    /// Enables the on-chip temperature sensor and bandgap voltage reference outputs.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name   | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 26:16 | CALIB  | R/W | Voltage Reference Calibration (11 bits).     |
    /// -----------------------------------------------------------------------
    /// |   2   | BGOUTEN| R/W | Bandgap Output Enable.                       |
    /// -----------------------------------------------------------------------
    /// |   1   | TSEN   | R/W | Temperature Sensor Enable.                   |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var vrefRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x40)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x40, newValue)
        }
    }

    /// VREF.TSEN – Temperature Sensor Enable
    ///
    /// When set, the internal temperature sensor output is routed to the ADC.
    @inline(__always)
    static var temperatureSensorEnable: Bool {
        get { (vrefRegister & (1 << 1)) != 0 }
        set {
            vrefRegister = newValue
                ? (vrefRegister | (1 << 1))
                : (vrefRegister & ~(1 << 1))
        }
    }

    /// VREF.BGOUTEN – Bandgap Output Enable
    ///
    /// When set, the bandgap voltage reference is routed to the VREF_OUT pin and ADC.
    @inline(__always)
    static var bandgapOutputEnable: Bool {
        get { (vrefRegister & (1 << 2)) != 0 }
        set {
            vrefRegister = newValue
                ? (vrefRegister | (1 << 2))
                : (vrefRegister & ~(1 << 2))
        }
    }

    /// VREF.CALIB – Voltage Reference Calibration (bits [26:16], 11 bits)
    ///
    /// Factory calibration loaded from NVM on reset.
    @inline(__always)
    static var vrefCalibration: UInt32 {
        get { (vrefRegister >> 16) & 0x7FF }
        set { vrefRegister = (vrefRegister & ~(0x7FF << 16)) | ((newValue & 0x7FF) << 16) }
    }


    // MARK: - DPLLCTRLA – FDPLL96M Control A (Offset 0x44, 8-bit)

    /// DPLLCTRLA – Fractional Digital PLL 96 MHz Control A Register
    /// See Section 17.8.17.
    ///
    /// Top-level enable and standby controls for the FDPLL96M.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name    | R/W | Description                                   |
    /// -----------------------------------------------------------------------
    /// |  7  | ONDEMAND| R/W | On Demand Control.                            |
    /// -----------------------------------------------------------------------
    /// |  6  | RUNSTDBY| R/W | Run in Standby.                               |
    /// -----------------------------------------------------------------------
    /// |  1  | ENABLE  | R/W | FDPLL96M Enable.                              |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dpllControlARegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x44) & 0x000000FF
        }
        set {
            let word = _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x44)
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x44, (word & 0xFFFFFF00) | (newValue & 0xFF))
        }
    }

    /// DPLLCTRLA.ENABLE
    @inline(__always)
    static var dpllEnable: Bool {
        get { (dpllControlARegister & (1 << 1)) != 0 }
        set {
            dpllControlARegister = newValue
                ? (dpllControlARegister | (1 << 1))
                : (dpllControlARegister & ~(1 << 1))
        }
    }

    /// DPLLCTRLA.RUNSTDBY
    @inline(__always)
    static var dpllRunInStandby: Bool {
        get { (dpllControlARegister & (1 << 6)) != 0 }
        set {
            dpllControlARegister = newValue
                ? (dpllControlARegister | (1 << 6))
                : (dpllControlARegister & ~(1 << 6))
        }
    }

    /// DPLLCTRLA.ONDEMAND
    @inline(__always)
    static var dpllOnDemand: Bool {
        get { (dpllControlARegister & (1 << 7)) != 0 }
        set {
            dpllControlARegister = newValue
                ? (dpllControlARegister | (1 << 7))
                : (dpllControlARegister & ~(1 << 7))
        }
    }


    // MARK: - DPLLRATIO – FDPLL96M Ratio Control (Offset 0x48, 32-bit)

    /// DPLLRATIO – FDPLL96M Ratio Control Register
    /// See Section 17.8.18.
    ///
    /// Sets the integer and fractional parts of the PLL multiplication ratio.
    /// The output frequency is: f_out = f_ref × (LDR + 1 + LDRFRAC/16)
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name    | R/W | Description                                 |
    /// -----------------------------------------------------------------------
    /// | 19:16 | LDRFRAC | R/W | Loop Divider Ratio Fractional Part (4 bits).|
    /// -----------------------------------------------------------------------
    /// | 11:0  | LDR     | R/W | Loop Divider Ratio Integer Part (12 bits).  |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dpllRatioRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x48)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x48, newValue)
        }
    }

    /// DPLLRATIO.LDR – Loop Divider Ratio Integer Part (bits [11:0])
    @inline(__always)
    static var dpllLoopDividerRatio: UInt32 {
        get { dpllRatioRegister & 0xFFF }
        set { dpllRatioRegister = (dpllRatioRegister & ~0xFFF) | (newValue & 0xFFF) }
    }

    /// DPLLRATIO.LDRFRAC – Loop Divider Ratio Fractional Part (bits [19:16])
    @inline(__always)
    static var dpllLoopDividerRatioFractional: UInt32 {
        get { (dpllRatioRegister >> 16) & 0x0F }
        set { dpllRatioRegister = (dpllRatioRegister & ~(0x0F << 16)) | ((newValue & 0x0F) << 16) }
    }


    // MARK: - DPLLCTRLB – FDPLL96M Control B (Offset 0x4C, 32-bit)

    /// DPLLCTRLB – FDPLL96M Control B Register
    /// See Section 17.8.19.
    ///
    /// Configures the FDPLL96M reference clock, loop filter, lock time, and output divider.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name   | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 26:16 | DIV    | R/W | Clock Divider (11 bits).                     |
    /// -----------------------------------------------------------------------
    /// |  12   | LBYPASS| R/W | Lock Bypass — ignore lock before outputting. |
    /// -----------------------------------------------------------------------
    /// | 10:8  | LTIME  | R/W | Lock Time. See DPLLLockTime enum.            |
    /// -----------------------------------------------------------------------
    /// |  5:4  | REFCLK | R/W | Reference Clock. See DPLLReferenceClockSource.|
    /// -----------------------------------------------------------------------
    /// |   3   | WUF    | R/W | Wake Up Fast — skip lock on wake.            |
    /// -----------------------------------------------------------------------
    /// |   2   | LPEN   | R/W | Low-Power Enable.                            |
    /// -----------------------------------------------------------------------
    /// |  1:0  | FILTER | R/W | PI Filter Selection. See DPLLFilter enum.    |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dpllControlBRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x4C)
        }
        set {
            _volatileRegisterWriteUInt32(SYSCTRL_BASE + 0x4C, newValue)
        }
    }

    /// DPLLCTRLB.FILTER – Proportional-Integral Filter Selection
    @inline(__always)
    static var dpllFilter: DPLLFilter {
        get {
            let f = dpllControlBRegister & 0x03
            return DPLLFilter(rawValue: f) ?? .default
        }
        set {
            dpllControlBRegister = (dpllControlBRegister & ~0x03) | (newValue.rawValue & 0x03)
        }
    }

    /// DPLLCTRLB.LPEN – Low-Power Enable
    ///
    /// When set, the FDPLL96M operates in a reduced-power mode with lower loop bandwidth.
    @inline(__always)
    static var dpllLowPowerEnable: Bool {
        get { (dpllControlBRegister & (1 << 2)) != 0 }
        set {
            dpllControlBRegister = newValue
                ? (dpllControlBRegister | (1 << 2))
                : (dpllControlBRegister & ~(1 << 2))
        }
    }

    /// DPLLCTRLB.WUF – Wake Up Fast
    ///
    /// When set, the FDPLL96M skips the lock sequence after waking from sleep
    /// and immediately asserts CLKRDY. Use only when the output frequency
    /// is not critical immediately after wake.
    @inline(__always)
    static var dpllWakeUpFast: Bool {
        get { (dpllControlBRegister & (1 << 3)) != 0 }
        set {
            dpllControlBRegister = newValue
                ? (dpllControlBRegister | (1 << 3))
                : (dpllControlBRegister & ~(1 << 3))
        }
    }

    /// DPLLCTRLB.REFCLK – Reference Clock Source
    @inline(__always)
    static var dpllReferenceClockSource: DPLLReferenceClockSource {
        get {
            let r = (dpllControlBRegister >> 4) & 0x03
            return DPLLReferenceClockSource(rawValue: r) ?? .xosc32K
        }
        set {
            dpllControlBRegister = (dpllControlBRegister & ~(0x03 << 4)) | ((newValue.rawValue & 0x03) << 4)
        }
    }

    /// DPLLCTRLB.LTIME – Lock Time
    ///
    /// Sets the maximum time allowed for the FDPLL96M to achieve lock. If lock is not
    /// achieved within this period, the DPLLLTO interrupt flag is set.
    @inline(__always)
    static var dpllLockTime: DPLLLockTime {
        get {
            let t = (dpllControlBRegister >> 8) & 0x07
            return DPLLLockTime(rawValue: t) ?? .noTimeout
        }
        set {
            dpllControlBRegister = (dpllControlBRegister & ~(0x07 << 8)) | ((newValue.rawValue & 0x07) << 8)
        }
    }

    /// DPLLCTRLB.LBYPASS – Lock Bypass
    ///
    /// When set, the FDPLL96M output is not gated by the lock signal. The output
    /// clock is available immediately regardless of whether the PLL has locked.
    @inline(__always)
    static var dpllLockBypass: Bool {
        get { (dpllControlBRegister & (1 << 12)) != 0 }
        set {
            dpllControlBRegister = newValue
                ? (dpllControlBRegister | (1 << 12))
                : (dpllControlBRegister & ~(1 << 12))
        }
    }

    /// DPLLCTRLB.DIV – Reference Clock Divider (bits [26:16], 11 bits)
    ///
    /// When REFCLK = XOSC, the reference is divided by (2 × (DIV + 1)) before
    /// being fed to the PLL. For XOSC32K or GCLK, DIV is ignored.
    @inline(__always)
    static var dpllReferenceDivider: UInt32 {
        get { (dpllControlBRegister >> 16) & 0x7FF }
        set { dpllControlBRegister = (dpllControlBRegister & ~(0x7FF << 16)) | ((newValue & 0x7FF) << 16) }
    }


    // MARK: - DPLLSTATUS – FDPLL96M Status (Offset 0x50, 8-bit, read-only)

    /// DPLLSTATUS – FDPLL96M Status Register
    /// See Section 17.8.20.
    ///
    /// Read-only register reporting the current state of the FDPLL96M.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bit | Name   |  R  | Description                                    |
    /// -----------------------------------------------------------------------
    /// |  3  | DIV    |  R  | '1' while the clock divider is enabled.        |
    /// -----------------------------------------------------------------------
    /// |  2  | ENABLE |  R  | '1' while the FDPLL96M is enabled.             |
    /// -----------------------------------------------------------------------
    /// |  1  | CLKRDY |  R  | '1' when the output clock is stable.           |
    /// -----------------------------------------------------------------------
    /// |  0  | LOCK   |  R  | '1' when the PLL has achieved frequency lock.  |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var dpllStatusRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(SYSCTRL_BASE + 0x50) & 0x000000FF
        }
    }

    /// DPLLSTATUS.LOCK – PLL Lock
    /// '1' while the FDPLL96M output frequency is locked to the reference.
    @inline(__always)
    static var dpllLocked: Bool {
        (dpllStatusRegister & (1 << 0)) != 0
    }

    /// DPLLSTATUS.CLKRDY – Output Clock Ready
    /// '1' when the FDPLL96M output clock is stable and usable.
    @inline(__always)
    static var dpllClockReady: Bool {
        (dpllStatusRegister & (1 << 1)) != 0
    }

    /// DPLLSTATUS.ENABLE – FDPLL96M Enabled (read-only)
    /// '1' while the FDPLL96M is powered and enabled.
    @inline(__always)
    static var dpllEnabled: Bool {
        (dpllStatusRegister & (1 << 2)) != 0
    }

    /// DPLLSTATUS.DIV – Clock Divider Enabled (read-only)
    /// '1' while the reference clock divider (DPLLCTRLB.DIV) is active.
    @inline(__always)
    static var dpllDividerEnabled: Bool {
        (dpllStatusRegister & (1 << 3)) != 0
    }
}
