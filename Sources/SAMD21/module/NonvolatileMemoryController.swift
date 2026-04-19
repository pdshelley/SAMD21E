//
//  NonvolatileMemoryController.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/19/26.
//

@usableFromInline let NVMCTRL_BASE: UInt = 0x41004000   // SAMD21 datasheet §22.8

/// Nonvolatile Memory Controller
///
/// The NVMCTRL manages reads, writes, and erase operations for the on-chip Flash
/// (main array) and auxiliary rows (user row, calibration row). It also controls
/// the read-wait-state configuration, the instruction cache, power-reduction mode,
/// and the per-region write-lock mechanism.
///
/// **Flash organisation (SAMD21E18A)**
///
/// - Main array: 256 KB at `0x00000000`–`0x0003FFFF`
/// - Page: 64 bytes (PARAM.PSZ = 3), row: 4 pages = 256 bytes
/// - 1 024 rows total, 16 lock regions of 16 rows each (16 KB per region)
///
/// **Auxiliary rows**
///
/// - User Row:              `0x0080_4000` (64 bytes, one page)
/// - Software Calibration:  `0x0080_6020`
/// - Serial Number words:   `0x0080_A00C`, `0x0080_A040`, `0x0080_A044`, `0x0080_A048`
///
/// **Typical write sequence**
///
///   1. Set `targetAddress` to the page-aligned byte address of the target page.
///   2. Execute `clearPageBuffer` to zero the page buffer.
///   3. Write 64 bytes to the target Flash address range using normal 32-bit stores.
///   4. Execute `writePage` (or rely on auto-write if `manualWrite` is `false`).
///   5. Poll `isReady` (or wait for the READY interrupt) before the next operation.
///
/// **Typical erase sequence**
///
///   1. Set `targetAddress` to any byte address within the target row.
///   2. Execute `eraseRow`.
///   3. Poll `isReady`.
///
/// APB clock must be enabled via `PowerManager.nvmctrlClockEnable` (always-on after reset).
///
/// See SAMD21 datasheet Section 22.
struct NonvolatileMemoryController {

    // MARK: - Supporting Enums

    /// NVM commands (CTRLA.CMD).
    ///
    /// Issue a command by calling `executeCommand(_:)`. The command execute key (0xA5) is
    /// written automatically. Never write CTRLA directly without the key — only 0xA5 arms
    /// the hardware to accept a command; any other key value is silently ignored.
    ///
    /// See SAMD21 datasheet Table 22-3.
    enum Command: UInt32 {
        /// Erase the 256-byte row containing `targetAddress`.
        case eraseRow              = 0x02
        /// Write the page buffer to the page indicated by `targetAddress`.
        case writePage             = 0x04
        /// Erase an auxiliary row (User Row / Calibration Row) at `targetAddress`.
        case eraseAuxiliaryRow     = 0x05
        /// Write the page buffer to an auxiliary row page at `targetAddress`.
        case writeAuxiliaryPage    = 0x06
        /// Write the current LOCK register state to the NVM lock bits.
        case writeLockBits         = 0x0F
        /// Lock the region containing `targetAddress` (clears the LOCK bit).
        case lockRegion            = 0x40
        /// Unlock the region containing `targetAddress` (sets the LOCK bit).
        case unlockRegion          = 0x41
        /// Enter NVM power-reduction mode (reduces standby current).
        case setPowerReductionMode = 0x42
        /// Exit NVM power-reduction mode.
        case clearPowerReductionMode = 0x43
        /// Clear the page buffer (zero all 64 bytes).
        case clearPageBuffer       = 0x44
        /// Set the security bit (irreversible; locks User Row and disables debug).
        case setSecurityBit        = 0x45
        /// Invalidate all instruction-cache lines.
        case invalidateCache       = 0x46
    }

    /// NVM read wait states (CTRLB.RWS).
    ///
    /// The CPU clock frequency determines the minimum required wait states.
    /// For the SAMD21 running at 48 MHz, set `.oneWaitState`.
    ///
    /// See SAMD21 datasheet Table 37-42.
    enum ReadWaitStates: UInt32 {
        case zeroWaitStates = 0   ///< Up to ~24 MHz.
        case oneWaitState   = 1   ///< Up to 48 MHz (required at 48 MHz).
        // Values 2–15 are valid but unused on the SAMD21.
    }

    /// NVM power-reduction mode during sleep (CTRLB.SLEEPPRM).
    ///
    /// See SAMD21 datasheet Table 22-5.
    enum SleepPowerReductionMode: UInt32 {
        /// Exit power reduction on first NVM access (default). Access adds latency.
        case wakeOnAccess  = 0
        /// NVM powered but in a reduced state during sleep; exits instantly on access.
        case wakeInstant   = 1
        /// Power reduction never applied; NVM always fully powered.
        case disabled      = 3
    }

    /// NVM cache-miss read mode (CTRLB.READMODE).
    ///
    /// See SAMD21 datasheet Table 22-6.
    enum ReadMode: UInt32 {
        /// No additional latency on a cache miss. Best throughput (default).
        case noMissPenalty  = 0
        /// Low-power read mode. May increase access time.
        case lowPower       = 1
        /// Deterministic read time regardless of cache state. Required when the
        /// CPU must not have variable instruction latency (e.g., hard real-time).
        case deterministic  = 2
    }

    /// NVM page size encoding (PARAM.PSZ).
    ///
    /// The actual page size in bytes is `8 << PSZ.rawValue` (i.e. 2^(PSZ+3)).
    /// The SAMD21 always uses `.bytes64` (PSZ = 3).
    ///
    /// See SAMD21 datasheet Table 22-8.
    enum PageSize: UInt32 {
        case bytes8    = 0
        case bytes16   = 1
        case bytes32   = 2
        case bytes64   = 3   ///< SAMD21 standard page size.
        case bytes128  = 4
        case bytes256  = 5
        case bytes512  = 6
        case bytes1024 = 7
    }


    // MARK: - CTRLA – NVM Control A (Offset 0x00, 16-bit)
    //
    // Shared 32-bit word at NVMCTRL_BASE + 0x00:
    //   [15:0]  = CTRLA
    //   [31:16] = reserved
    //
    // CTRLA is primarily a write register. To issue a command:
    //   • Write CMD[7:0]  = command code.
    //   • Write CMDEX[15:8] = 0xA5  (execute key — must be written together with CMD).
    // Only the 0xA5 key arms the hardware; any other CMDEX value is silently ignored.

    /// CTRLA – NVM Control A Register
    /// See Section 22.8.1.
    ///
    /// Write via `executeCommand(_:)` rather than directly. Reading back returns the
    /// last command written (not the current hardware state).
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name   | R/W | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 15:8  | CMDEX  | R/W | Command Execute key — must be 0xA5.          |
    /// -----------------------------------------------------------------------
    /// |  7:0  | CMD    | R/W | NVM Command. See Command enum.               |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var controlARegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x00) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x00)
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x00, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// Issue an NVM command.
    ///
    /// Writes the command code and the mandatory execute key (0xA5) to CTRLA in a
    /// single 16-bit write. The `targetAddress` register must be loaded before calling
    /// this function for any address-targeted command (erase, write, lock, unlock).
    ///
    /// After issuing a command, poll `isReady` before performing any further NVM access.
    @inline(__always)
    static func executeCommand(_ cmd: Command) {
        controlARegister = (0xA5 << 8) | cmd.rawValue
    }


    // MARK: - CTRLB – NVM Control B (Offset 0x04, 32-bit)

    /// CTRLB – NVM Control B Register
    /// See Section 22.8.2.
    ///
    /// Configuration register. Writes take effect immediately; the cache should be
    /// invalidated (`executeCommand(.invalidateCache)`) if `readWaitStates` or
    /// `cacheDisable` are changed after the first instruction fetch.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name      | R/W | Description                               |
    /// -----------------------------------------------------------------------
    /// |  18   | CACHEDIS  | R/W | Cache Disable — bypass instruction cache. |
    /// -----------------------------------------------------------------------
    /// | 17:16 | READMODE  | R/W | Read Mode. See ReadMode enum.             |
    /// -----------------------------------------------------------------------
    /// |  9:8  | SLEEPPRM  | R/W | Sleep Power Reduction. See enum.          |
    /// -----------------------------------------------------------------------
    /// |   7   | MANW      | R/W | Manual Write mode (1 = WP command needed).|
    /// -----------------------------------------------------------------------
    /// |  4:1  | RWS       | R/W | Read Wait States. See ReadWaitStates enum.|
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var controlBRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x04)
        }
        set {
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x04, newValue)
        }
    }

    /// CTRLB.RWS – NVM Read Wait States (bits [4:1])
    ///
    /// Must match the CPU operating frequency. At 48 MHz (typical for USB operation)
    /// at least one wait state is required. Set this before raising the CPU clock.
    @inline(__always)
    static var readWaitStates: UInt32 {
        get {
            (controlBRegister >> 1) & 0x0F
        }
        set {
            controlBRegister = (controlBRegister & ~(0x0F << 1)) | ((newValue & 0x0F) << 1)
        }
    }

    /// CTRLB.MANW – Manual Write
    ///
    /// `false` (default): the page buffer is flushed to NVM automatically when full.
    /// `true`: the page buffer is only written on an explicit `writePage` command,
    /// giving firmware precise control over write timing.
    @inline(__always)
    static var manualWrite: Bool {
        get { (controlBRegister & (1 << 7)) != 0 }
        set {
            controlBRegister = newValue
                ? (controlBRegister | (1 << 7))
                : (controlBRegister & ~(1 << 7))
        }
    }

    /// CTRLB.SLEEPPRM – Sleep Power Reduction Mode (bits [9:8])
    @inline(__always)
    static var sleepPowerReduction: SleepPowerReductionMode {
        get {
            let s = (controlBRegister >> 8) & 0x03
            return SleepPowerReductionMode(rawValue: s) ?? .wakeOnAccess
        }
        set {
            controlBRegister = (controlBRegister & ~(0x03 << 8)) | ((newValue.rawValue & 0x03) << 8)
        }
    }

    /// CTRLB.READMODE – Cache-Miss Read Mode (bits [17:16])
    @inline(__always)
    static var readMode: ReadMode {
        get {
            let m = (controlBRegister >> 16) & 0x03
            return ReadMode(rawValue: m) ?? .noMissPenalty
        }
        set {
            controlBRegister = (controlBRegister & ~(0x03 << 16)) | ((newValue.rawValue & 0x03) << 16)
        }
    }

    /// CTRLB.CACHEDIS – Instruction Cache Disable
    ///
    /// When set, all instruction fetches bypass the cache and go directly to NVM.
    /// Disabling the cache is rarely needed in production firmware; it is mainly
    /// useful for testing worst-case read timing.
    @inline(__always)
    static var cacheDisable: Bool {
        get { (controlBRegister & (1 << 18)) != 0 }
        set {
            controlBRegister = newValue
                ? (controlBRegister | (1 << 18))
                : (controlBRegister & ~(1 << 18))
        }
    }


    // MARK: - PARAM – NVM Parameter (Offset 0x08, 32-bit, read-only)

    /// PARAM – NVM Parameter Register
    /// See Section 22.8.3.
    ///
    /// Read-only register populated by hardware from factory calibration data.
    /// Use `nvmPageCount`, `pageSize`, and `rwwEEPROMPageCount` for individual fields.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name   | R   | Description                                  |
    /// -----------------------------------------------------------------------
    /// | 31:20 | RWWEEP | R   | Number of RWW EEPROM pages (0 on SAMD21E).  |
    /// -----------------------------------------------------------------------
    /// | 18:16 | PSZ    | R   | Page size encoding. See PageSize enum.       |
    /// -----------------------------------------------------------------------
    /// | 15:0  | NVMP   | R   | Number of NVM pages in the main array.       |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var parameterRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x08)
        }
    }

    /// PARAM.NVMP – Number of NVM Pages in the main array (bits [15:0], read-only)
    ///
    /// For the SAMD21E18A (256 KB Flash, 64-byte pages): NVMP = 4096.
    @inline(__always)
    static var nvmPageCount: UInt32 {
        parameterRegister & 0xFFFF
    }

    /// PARAM.PSZ – Page Size Encoding (bits [18:16], read-only)
    ///
    /// The actual page size in bytes is `8 << PSZ.rawValue`. For SAMD21 this is always
    /// `.bytes64` (PSZ = 3, page = 64 bytes).
    @inline(__always)
    static var pageSize: PageSize {
        let p = (parameterRegister >> 16) & 0x07
        return PageSize(rawValue: p) ?? .bytes64
    }

    /// PARAM.RWWEEP – RWW EEPROM Page Count (bits [31:20], read-only)
    ///
    /// Number of Read-While-Write EEPROM emulation pages. Zero on SAMD21E variants
    /// that do not include the RWW EEPROM section.
    @inline(__always)
    static var rwwEEPROMPageCount: UInt32 {
        (parameterRegister >> 20) & 0xFFF
    }


    // MARK: - INTENCLR / INTENSET / INTFLAG
    //
    // Each is an 8-bit register in its own 32-bit aligned word.
    // INTENCLR and INTENSET are write-1-to-clear/set; INTFLAG is write-1-to-clear.
    // Writing 0 to any of these registers has no effect — no read-modify-write needed.
    //
    // Interrupt bit positions (shared across all three registers):
    //   Bit 0: READY – NVM operation complete.
    //   Bit 1: ERROR – NVM error (PROGE, LOCKE, or NVME set in STATUS).

    /// INTENCLR – Interrupt Enable Clear Register
    /// See Section 22.8.4.
    ///
    /// Reading returns the current interrupt enable state.
    /// Writing '1' to a bit disables the corresponding interrupt; writing '0' has no effect.
    @inline(__always)
    static var interruptEnableClearRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x0C) & 0x000000FF
        }
        set {
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x0C, newValue & 0xFF)
        }
    }

    /// INTENSET – Interrupt Enable Set Register
    /// See Section 22.8.5.
    ///
    /// Reading returns the current interrupt enable state.
    /// Writing '1' to a bit enables the corresponding interrupt; writing '0' has no effect.
    @inline(__always)
    static var interruptEnableSetRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x10) & 0x000000FF
        }
        set {
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x10, newValue & 0xFF)
        }
    }

    /// INTFLAG – Interrupt Flag Status and Clear Register
    /// See Section 22.8.6.
    ///
    /// Bits are set by hardware. Write '1' to clear a flag.
    @inline(__always)
    static var interruptFlagRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x14) & 0x000000FF
        }
        set {
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x14, newValue & 0xFF)
        }
    }

    @inline(__always)
    private static func interruptEnable(bit: UInt32) -> Bool {
        (interruptEnableClearRegister & (1 << bit)) != 0
    }

    @inline(__always)
    private static func setInterruptEnable(bit: UInt32, _ enabled: Bool) {
        if enabled { interruptEnableSetRegister = (1 << bit) }
        else        { interruptEnableClearRegister = (1 << bit) }
    }

    /// READY – NVM Operation Complete interrupt enable.
    ///
    /// The READY flag is set when an erase, write, or command operation finishes
    /// and the NVM is ready for the next access.
    @inline(__always)
    static var readyInterruptEnable: Bool {
        get { interruptEnable(bit: 0) }
        set { setInterruptEnable(bit: 0, newValue) }
    }

    /// ERROR – NVM Error interrupt enable.
    ///
    /// The ERROR flag is set simultaneously with STATUS.NVME when a programming
    /// error (PROGE) or lock error (LOCKE) occurs.
    @inline(__always)
    static var errorInterruptEnable: Bool {
        get { interruptEnable(bit: 1) }
        set { setInterruptEnable(bit: 1, newValue) }
    }

    // INTFLAG status and clear

    /// INTFLAG.READY – NVM ready flag.
    ///
    /// Set by hardware when an operation completes. Write `true` to clear.
    /// Poll this flag (or use the interrupt) after every `executeCommand(_:)` call
    /// before performing any other NVM access.
    @inline(__always)
    static var isReady: Bool {
        get { (interruptFlagRegister & (1 << 0)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 0) } }
    }

    /// INTFLAG.ERROR – NVM error flag.
    ///
    /// Set by hardware when STATUS.NVME becomes set. Write `true` to clear.
    @inline(__always)
    static var hasError: Bool {
        get { (interruptFlagRegister & (1 << 1)) != 0 }
        set { if newValue { interruptFlagRegister = (1 << 1) } }
    }


    // MARK: - STATUS – NVM Status (Offset 0x18, 16-bit)
    //
    // Shared 32-bit word at NVMCTRL_BASE + 0x18:
    //   [15:0]  = STATUS
    //   [31:16] = reserved
    //
    // Bit layout:
    //   Bit  0: PRM   – Power Reduction Mode active (read-only).
    //   Bit  1: LOAD  – Page buffer loaded with unwritten data (read-only).
    //   Bit  2: PROGE – Programming error (write-1-to-clear).
    //   Bit  3: LOCKE – Lock error (write-1-to-clear).
    //   Bit  4: NVME  – NVM error summary (write-1-to-clear; set when PROGE or LOCKE is set).
    //   Bit  8: SB    – Security bit set (read-only; set by SSB command; irreversible).

    /// STATUS – NVM Status Register
    /// See Section 22.8.7.
    ///
    /// Reading returns current NVM state. Error bits (PROGE, LOCKE, NVME) are
    /// write-1-to-clear; the remaining bits are read-only.
    @inline(__always)
    static var statusRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x18) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x18)
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x18, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// STATUS.PRM – Power Reduction Mode Active (read-only)
    ///
    /// Set while the NVM is in power-reduction mode (entered via `setPowerReductionMode`
    /// command, cleared via `clearPowerReductionMode` command or an NVM access).
    @inline(__always)
    static var isPowerReductionModeActive: Bool {
        (statusRegister & (1 << 0)) != 0
    }

    /// STATUS.LOAD – Page Buffer Loaded (read-only)
    ///
    /// Set by hardware when at least one word has been written to the page buffer
    /// since the last `clearPageBuffer` or `writePage` command. Indicates there is
    /// data in the buffer that has not yet been committed to NVM.
    @inline(__always)
    static var isPageBufferLoaded: Bool {
        (statusRegister & (1 << 1)) != 0
    }

    /// STATUS.PROGE – Programming Error (write-1-to-clear)
    ///
    /// Set when a command is attempted with an invalid address or when a write is
    /// attempted to a page that was not erased first.
    @inline(__always)
    static var programmingError: Bool {
        get { (statusRegister & (1 << 2)) != 0 }
        set { if newValue { statusRegister = (1 << 2) } }
    }

    /// STATUS.LOCKE – Lock Error (write-1-to-clear)
    ///
    /// Set when a write or erase is attempted on a locked region.
    @inline(__always)
    static var lockError: Bool {
        get { (statusRegister & (1 << 3)) != 0 }
        set { if newValue { statusRegister = (1 << 3) } }
    }

    /// STATUS.NVME – NVM Error (write-1-to-clear)
    ///
    /// Summary flag: set whenever PROGE or LOCKE is set. Clearing NVME also clears
    /// PROGE and LOCKE. This is also mirrored in INTFLAG.ERROR.
    @inline(__always)
    static var nvmError: Bool {
        get { (statusRegister & (1 << 4)) != 0 }
        set { if newValue { statusRegister = (1 << 4) } }
    }

    /// STATUS.SB – Security Bit (read-only)
    ///
    /// Set permanently by the `setSecurityBit` command. Once set, the chip cannot
    /// be programmed via the debug interface and the User Row becomes read-protected.
    /// This cannot be cleared without a full chip erase.
    @inline(__always)
    static var isSecurityBitSet: Bool {
        (statusRegister & (1 << 8)) != 0
    }


    // MARK: - ADDR – NVM Address (Offset 0x1C, 32-bit)

    /// ADDR – NVM Address Register
    /// See Section 22.8.8.
    ///
    /// Specifies the target NVM address for the next erase, write, lock, or unlock command.
    ///
    /// The register holds the **word address** (16-bit word granularity). To convert a
    /// byte address to a word address: `wordAddress = byteAddress >> 1`.
    ///
    /// For a row erase, any address within the target row is sufficient — the hardware
    /// automatically aligns to the row boundary. For a page write, the address should
    /// point to the start of the target page.
    ///
    /// For auxiliary rows use the auxiliary row byte address (e.g. `0x00804000` for the
    /// User Row), shifted right by 1.
    ///
    /// ```
    /// -----------------------------------------------------------------------
    /// | Bits  | Name | R/W | Description                                    |
    /// -----------------------------------------------------------------------
    /// | 21:0  | ADDR | R/W | NVM word address (byte address >> 1).          |
    /// -----------------------------------------------------------------------
    /// ```
    @inline(__always)
    static var targetAddress: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x1C) & 0x003FFFFF
        }
        set {
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x1C, newValue & 0x003FFFFF)
        }
    }


    // MARK: - LOCK – Lock Section (Offset 0x20, 16-bit)
    //
    // Shared 32-bit word at NVMCTRL_BASE + 0x20:
    //   [15:0]  = LOCK
    //   [31:16] = reserved

    /// LOCK – Lock Section Register
    /// See Section 22.8.9.
    ///
    /// One bit per lock region. The SAMD21E18A has 16 lock regions of 16 KB each
    /// (one bit per 16 pages × 64 bytes = 16 384 bytes).
    ///
    /// Bit meaning:
    ///   `0` – region is **locked**; write and erase operations are blocked.
    ///   `1` – region is **unlocked**; write and erase operations are permitted.
    ///
    /// The lock state is stored in NVM. To change the lock state at runtime:
    ///   1. Set `targetAddress` to any address within the target region.
    ///   2. Issue `lockRegion` or `unlockRegion`.
    ///   3. Issue `writeLockBits` to persist the new state to NVM.
    ///
    /// Reading this register reflects the current (RAM-side) lock state, which may
    /// differ from NVM until `writeLockBits` is executed.
    @inline(__always)
    static var lockRegister: UInt32 {
        get {
            _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x20) & 0x0000FFFF
        }
        set {
            let word = _volatileRegisterReadUInt32(NVMCTRL_BASE + 0x20)
            _volatileRegisterWriteUInt32(NVMCTRL_BASE + 0x20, (word & 0xFFFF0000) | (newValue & 0xFFFF))
        }
    }

    /// Returns `true` if lock region `region` (0–15) is currently unlocked.
    ///
    /// Region 0 covers the lowest 16 KB of Flash (0x0000_0000–0x0000_3FFF).
    /// Region 15 covers the highest 16 KB (0x0003_C000–0x0003_FFFF).
    @inline(__always)
    static func isRegionUnlocked(region: UInt) -> Bool {
        (lockRegister & (1 << region)) != 0
    }
}
