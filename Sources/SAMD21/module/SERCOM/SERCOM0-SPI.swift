//
//  SERCOM0-SPI.swift
//  SAMD21E
//
//  Created by Paul Shelley on 5/5/26.
//


@usableFromInline let SERCOM0_BASE: UInt = 0x42000800


struct SERCOM0 {

    struct SPI {
        
        // MARK: - CTRLA
        
        /// SPI Control A - CTRLA
        @inline(__always)
        static var controlA: UInt32 {
            get {
                _volatileRegisterReadUInt32(SERCOM0_BASE)
            }
            set {
                _volatileRegisterWriteUInt32(SERCOM0_BASE, newValue)
            }
        }
        
        /// Software Reset - SWRST - Bit 0
        ///
        /// Writing '0' to this bit has no effect.
        /// Writing '1' to this bit resets all registers in the SERCOM, except DBGCTRL, to their initial state, and
        /// the SERCOM will be disabled.
        /// Writing ''1' to CTRL.SWRST will always take precedence, meaning that all other writes in the same
        /// write-operation will be discarded. Any register write access during the ongoing reset will result in an
        /// APB error. Reading any register will return the reset value of the register.
        /// Due to synchronization, there is a delay from writing CTRLA.SWRST until the reset is complete.
        /// CTRLA.SWRST and SYNCBUSY. SWRST will both be cleared when the reset is complete.
        ///
        /// This bit is not enable-protected.
        /// ```
        /// ----------------------------------------------------------
        /// | Value | Description                                    |
        /// ----------------------------------------------------------
        /// | false | There is no reset operation ongoing.           |
        /// ----------------------------------------------------------
        /// | 2true | The reset operation is ongoing.                |
        /// ----------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var softwareReset: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 0)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 0)) | (newValue ? 1 << 0 : 0) }
        }
        
        /// Enable - ENABLE - Bit 1
        ///
        /// Due to synchronization, there is delay from writing CTRLA.ENABLE until the peripheral is
        /// enabled/disabled. The value written to CTRL.ENABLE will read back immediately and the
        /// Synchronization Enable Busy bit in the Synchronization Busy register (SYNCBUSY.ENABLE) will be
        /// set. SYNCBUSY.ENABLE is cleared when the operation is complete.
        ///
        /// This bit is not enable-protected.
        /// ```
        /// ----------------------------------------------------------
        /// | Value | Description                                    |
        /// ----------------------------------------------------------
        /// | false | The peripheral is disabled or being disabled.  |
        /// ----------------------------------------------------------
        /// | 2true | The peripheral is enabled or being enabled.    |
        /// ----------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var enable: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 1)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 1)) | (newValue ? (1 << 1) : 0) }
        }
        
        /// Operating Mode
        ///
        /// ```
        /// ----------------------------------------------------------
        /// | Value | Description                                    |
        /// ----------------------------------------------------------
        /// | 0x2   | SPI client operation                           |
        /// ----------------------------------------------------------
        /// | 0x3   | SPI host operation                             |
        /// ----------------------------------------------------------
        /// ```
        enum OperatingMode: UInt32 {
            case client = 2
            case host = 3
        }
        
        /// Operating Mode - MODE - Bits 4:2
        ///
        /// These bits must be written to 0x2 or 0x3 to select the SPI serial communication interface of the
        /// SERCOM.
        ///
        /// These bits are not synchronized.
        /// ```
        /// ----------------------------------------------------------
        /// | Value | Description                                    |
        /// ----------------------------------------------------------
        /// | 0x2   | SPI client operation                           |
        /// ----------------------------------------------------------
        /// | 0x3   | SPI host operation                             |
        /// ----------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var operatingMode: OperatingMode {
            get {
                let raw = (SERCOM0.SPI.controlA >> 2) & 0x07
                return OperatingMode(rawValue: raw) ?? .host
            }
            set {
                SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(0x07 << 2)) | ((newValue.rawValue & 0x07) << 2)
            }
        }
        
        /// Run during Standby - RUNSTDBY - Bit 7
        ///
        /// This bit defines the functionality in standby sleep mode.
        /// These bits are not synchronized.
        /// ```
        /// ---------------------------------------------------------------------------------------------------------------------
        /// | Value | Client                                            | Host                                                  |
        /// ---------------------------------------------------------------------------------------------------------------------
        /// | false | Disabled. All reception is dropped, including the | Generic clock is disabled when ongoing transaction is |
        /// |       | ongoing transaction.                              | finished. All interrupts can wake up the device.      |
        /// ---------------------------------------------------------------------------------------------------------------------
        /// | true  | Ongoing transaction continues, wake on Receive    | Generic clock is enabled while in sleep modes. All    |
        /// |       | Complete interrupt.                               | interrupts can wake up the device.                    |
        /// ---------------------------------------------------------------------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var runInStandby: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 7)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 7)) | (newValue ? 1 << 7 : 0) }
        }
        
        /// Immediate Buffer Overflow Notification - IBON - Bit 8
        ///
        /// This bit controls when the buffer overflow status bit (STATUS.BUFOVF) is set when a buffer overflow
        /// occurs.
        /// This bit is not synchronized.
        /// ```
        /// -------------------------------------------------------------------
        /// | Value | Description                                             |
        /// -------------------------------------------------------------------
        /// | 0x2   | STATUS.BUFOVF is set when it occurs in the data stream. |
        /// -------------------------------------------------------------------
        /// | 0x3   | STATUS.BUFOVF is set immediately upon buffer overflow.  |
        /// -------------------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var immediateBufferOverflowNotification: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 8)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 8)) | (newValue ? 1 << 8 : 0) }
        }
        
        /// Data Out Pinout
        ///
        /// ```
        /// ------------------------------------------------------------------------------------------------------
        /// | Value | DO     | SCK    | Client SS | Host SS (MSSEN = 1) | Host SS (MSSEN = 0)                    |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x0   | PAD[0] | PAD[1] | PAD[2]    | PAD[2]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x1   | PAD[2] | PAD[3] | PAD[1]    | PAD[1]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x2   | PAD[3] | PAD[1] | PAD[2]    | PAD[2]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x3   | PAD[0] | PAD[3] | PAD[1]    | PAD[1]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// ```
        enum DataOutPinout: UInt32 {
            case mosi0_sck1 = 0
            case mosi2_sck3 = 1
            case mosi3_sck1 = 2
            case mosi0_sck3 = 3
        }
        
        /// Data Out Pinout - DOPO - Bits 17:16
        ///
        /// This bit defines the available pad configurations for data out (DO), the serial clock (SCK) and the SPI
        /// select (SS). In Client operation, the SPI Select line (SS) is controlled by DOPO. In host operation, the
        /// SPI Select line (SS) is either controlled by DOPO when CTRLB.MSSEN = 1, or by a GPIO driven by the
        /// application when CTRLB.MSSEN = 0.
        /// In host operation, DO is MOSI.
        /// In client operation, DO is MISO.
        /// These bits are not synchronized.
        /// ```
        /// ------------------------------------------------------------------------------------------------------
        /// | Value | DO     | SCK    | Client SS | Host SS (MSSEN = 1) | Host SS (MSSEN = 0)                    |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x0   | PAD[0] | PAD[1] | PAD[2]    | PAD[2]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x1   | PAD[2] | PAD[3] | PAD[1]    | PAD[1]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x2   | PAD[3] | PAD[1] | PAD[2]    | PAD[2]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// | 0x3   | PAD[0] | PAD[3] | PAD[1]    | PAD[1]              | Any GPIO configured by the application |
        /// ------------------------------------------------------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var dataOutPinout: DataOutPinout {
            get {
                DataOutPinout(rawValue: (SERCOM0.SPI.controlA >> 16) & 0x03) ?? .mosi0_sck1
            }
            set {
                SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(0x03 << 16)) | ((newValue.rawValue & 0x03) << 16)
            }
        }
        
        /// Data In Pinout
        ///
        /// ```
        /// --------------------------------------------------------------
        /// | Value | Name   | Description                               |
        /// --------------------------------------------------------------
        /// | 0x0   | PAD[0] | SERCOM PAD[0] is used as data input       |
        /// --------------------------------------------------------------
        /// | 0x1   | PAD[1] | SERCOM PAD[1] is used as data input       |
        /// --------------------------------------------------------------
        /// | 0x2   | PAD[2] | SERCOM PAD[2] is used as data input       |
        /// --------------------------------------------------------------
        /// | 0x3   | PAD[3] | SERCOM PAD[3] is used as data input       |
        /// --------------------------------------------------------------
        /// ```
        enum DataInPinout: UInt32 {
            case miso0 = 0
            case miso1 = 1
            case miso2 = 2
            case miso3 = 3
        }
        
        /// Data In Pinout - DIPO - Bits 21:20
        ///
        /// These bits define the data in (DI) pad configurations.
        /// In host operation, DI is MISO.
        /// In client operation, DI is MOSI.
        /// These bits are not synchronized.
        /// ```
        /// --------------------------------------------------------------
        /// | Value | Name   | Description                               |
        /// --------------------------------------------------------------
        /// | 0x0   | PAD[0] | SERCOM PAD[0] is used as data input       |
        /// --------------------------------------------------------------
        /// | 0x1   | PAD[1] | SERCOM PAD[1] is used as data input       |
        /// --------------------------------------------------------------
        /// | 0x2   | PAD[2] | SERCOM PAD[2] is used as data input       |
        /// --------------------------------------------------------------
        /// | 0x3   | PAD[3] | SERCOM PAD[3] is used as data input       |
        /// --------------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var dataInPinout: DataInPinout {
            get {
                DataInPinout(rawValue: (SERCOM0.SPI.controlA >> 20) & 0x03) ?? .miso0
            }
            set {
                SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(0x03 << 20)) | ((newValue.rawValue & 0x03) << 20)
            }
        }
        
        /// FORM: Frame Format
        @inlinable @inline(__always)
        static var form: UInt32 {
            get { (SERCOM0.SPI.controlA >> 24) & 0x0F }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(UInt32(0x0F) << 24)) | ((newValue & 0x0F) << 24) }
        }
        
        /// CPHA: Clock Phase
        @inlinable @inline(__always)
        static var cpha: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 28)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 28)) | (newValue ? 1 << 28 : 0) }
        }
        
        /// CPOL: Clock Polarity
        @inlinable @inline(__always)
        static var cpol: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 29)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 29)) | (newValue ? 1 << 29 : 0) }
        }
        
        /// DORD: Data Order
        @inlinable @inline(__always)
        static var dord: Bool {
            get { (SERCOM0.SPI.controlA & (1 << 30)) != 0 }
            set { SERCOM0.SPI.controlA = (SERCOM0.SPI.controlA & ~(1 << 30)) | (newValue ? 1 << 30 : 0) }
        }
        
        // MARK: - CTRLB
        
        /// SPI Control B - CTRLB
        /// CHSIZE: Character Size
        /// PLOADEN: Data Preload Enable
        /// SSDE: Slave Select Low Detect Enable
        /// MSSEN: Master Slave Select Enable
        /// AMODE: Address Mode
        /// RXEN: Receiver Enable
        @inline(__always)
        static var ctrlb: UInt32 {
            get {
                _volatileRegisterReadUInt32(SERCOM0_BASE + 0x04)
            }
            set {
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x04, newValue)
            }
        }
        
        /// CHSIZE: Character Size
        @inlinable @inline(__always)
        static var chsize: UInt32 {
            get { SERCOM0.SPI.ctrlb & 0x07 }
            set { SERCOM0.SPI.ctrlb = (SERCOM0.SPI.ctrlb & ~UInt32(0x07)) | (newValue & 0x07) }
        }
        
        /// PLOADEN: Data Preload Enable
        @inlinable @inline(__always)
        static var ploaden: Bool {
            get { (SERCOM0.SPI.ctrlb & (1 << 6)) != 0 }
            set { SERCOM0.SPI.ctrlb = (SERCOM0.SPI.ctrlb & ~(1 << 6)) | (newValue ? 1 << 6 : 0) }
        }
        
        /// SSDE: Slave Select Low Detect Enable
        @inlinable @inline(__always)
        static var ssde: Bool {
            get { (SERCOM0.SPI.ctrlb & (1 << 9)) != 0 }
            set { SERCOM0.SPI.ctrlb = (SERCOM0.SPI.ctrlb & ~(1 << 9)) | (newValue ? 1 << 9 : 0) }
        }
        
        /// Master Slave Select Enable - MSSEN - Bit 13
        ///
        /// This bit enables hardware SPI Select (SS) control.
        /// This bit is not synchronized.
        /// ```
        /// ----------------------------------------------------------
        /// | Value | Description                                    |
        /// ----------------------------------------------------------
        /// | false | Hardware SS control is disabled.               |
        /// ----------------------------------------------------------
        /// | true  | Hardware SS control is enabled.                |
        /// ----------------------------------------------------------
        /// ```
        @inlinable @inline(__always)
        static var masterSlaveSelectEnable: Bool {
            get { (SERCOM0.SPI.ctrlb & (1 << 13)) != 0 }
            set { SERCOM0.SPI.ctrlb = (SERCOM0.SPI.ctrlb & ~(1 << 13)) | (newValue ? 1 << 13 : 0) }
        }
        
        /// AMODE: Address Mode
        @inlinable @inline(__always)
        static var amode: UInt32 {
            get { (SERCOM0.SPI.ctrlb >> 14) & 0x03 }
            set { SERCOM0.SPI.ctrlb = (SERCOM0.SPI.ctrlb & ~(UInt32(0x03) << 14)) | ((newValue & 0x03) << 14) }
        }
        
        /// RXEN: Receiver Enable
        @inlinable @inline(__always)
        static var rxen: Bool {
            get { (SERCOM0.SPI.ctrlb & (1 << 17)) != 0 }
            set { SERCOM0.SPI.ctrlb = (SERCOM0.SPI.ctrlb & ~(1 << 17)) | (newValue ? 1 << 17 : 0) }
        }
        
        // MARK: - BAUD
        
        /// SPI Baud Rate - BAUD
        /// BAUD: Baud Rate Value
        /// Single-field register; baud var is the BAUD field directly.
        @inline(__always)
        static var baud: UInt32 {
            get {
                (_volatileRegisterReadUInt32(SERCOM0_BASE + 0x0C) >> 0) & 0x000000FF
            }
            set {
                let word = _volatileRegisterReadUInt32(SERCOM0_BASE + 0x0C)
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x0C, (word & 0xFFFFFF00) | ((newValue & 0xFF) << 0))
            }
        }
        
        // MARK: - INTENCLR
        
        /// SPI Interrupt Enable Clear - INTENCLR
        /// DRE: Data Register Empty Interrupt Disable
        /// TXC: Transmit Complete Interrupt Disable
        /// RXC: Receive Complete Interrupt Disable
        /// SSL: Slave Select Low Interrupt Disable
        /// ERROR: Combined Error Interrupt Disable
        @inline(__always)
        static var intenclr: UInt32 {
            get {
                (_volatileRegisterReadUInt32(SERCOM0_BASE + 0x14) >> 0) & 0x000000FF
            }
            set {
                let word = _volatileRegisterReadUInt32(SERCOM0_BASE + 0x14)
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x14, (word & 0xFFFFFF00) | ((newValue & 0xFF) << 0))
            }
        }
        
        /// DRE: Data Register Empty Interrupt Disable
        @inlinable @inline(__always)
        static var intenclrDRE: Bool {
            get { (SERCOM0.SPI.intenclr & (1 << 0)) != 0 }
            set { SERCOM0.SPI.intenclr = (SERCOM0.SPI.intenclr & ~(1 << 0)) | (newValue ? 1 << 0 : 0) }
        }
        
        /// TXC: Transmit Complete Interrupt Disable
        @inlinable @inline(__always)
        static var intenclrTXC: Bool {
            get { (SERCOM0.SPI.intenclr & (1 << 1)) != 0 }
            set { SERCOM0.SPI.intenclr = (SERCOM0.SPI.intenclr & ~(1 << 1)) | (newValue ? 1 << 1 : 0) }
        }
        
        /// RXC: Receive Complete Interrupt Disable
        @inlinable @inline(__always)
        static var intenclrRXC: Bool {
            get { (SERCOM0.SPI.intenclr & (1 << 2)) != 0 }
            set { SERCOM0.SPI.intenclr = (SERCOM0.SPI.intenclr & ~(1 << 2)) | (newValue ? 1 << 2 : 0) }
        }
        
        /// SSL: Slave Select Low Interrupt Disable
        @inlinable @inline(__always)
        static var intenclrSSL: Bool {
            get { (SERCOM0.SPI.intenclr & (1 << 3)) != 0 }
            set { SERCOM0.SPI.intenclr = (SERCOM0.SPI.intenclr & ~(1 << 3)) | (newValue ? 1 << 3 : 0) }
        }
        
        /// ERROR: Combined Error Interrupt Disable
        @inlinable @inline(__always)
        static var intenclrERROR: Bool {
            get { (SERCOM0.SPI.intenclr & (1 << 7)) != 0 }
            set { SERCOM0.SPI.intenclr = (SERCOM0.SPI.intenclr & ~(1 << 7)) | (newValue ? 1 << 7 : 0) }
        }
        
        // MARK: - INTENSET
        
        /// SPI Interrupt Enable Set - INTENSET
        /// DRE: Data Register Empty Interrupt Enable
        /// TXC: Transmit Complete Interrupt Enable
        /// RXC: Receive Complete Interrupt Enable
        /// SSL: Slave Select Low Interrupt Enable
        /// ERROR: Combined Error Interrupt Enable
        @inline(__always)
        static var intenset: UInt32 {
            get {
                (_volatileRegisterReadUInt32(SERCOM0_BASE + 0x14) >> 16) & 0x000000FF
            }
            set {
                let word = _volatileRegisterReadUInt32(SERCOM0_BASE + 0x14)
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x14, (word & 0xFF00FFFF) | ((newValue & 0xFF) << 16))
            }
        }
        
        /// DRE: Data Register Empty Interrupt Enable
        @inlinable @inline(__always)
        static var intensetDRE: Bool {
            get { (SERCOM0.SPI.intenset & (1 << 0)) != 0 }
            set { SERCOM0.SPI.intenset = (SERCOM0.SPI.intenset & ~(1 << 0)) | (newValue ? 1 << 0 : 0) }
        }
        
        /// TXC: Transmit Complete Interrupt Enable
        @inlinable @inline(__always)
        static var intensetTXC: Bool {
            get { (SERCOM0.SPI.intenset & (1 << 1)) != 0 }
            set { SERCOM0.SPI.intenset = (SERCOM0.SPI.intenset & ~(1 << 1)) | (newValue ? 1 << 1 : 0) }
        }
        
        /// RXC: Receive Complete Interrupt Enable
        @inlinable @inline(__always)
        static var intensetRXC: Bool {
            get { (SERCOM0.SPI.intenset & (1 << 2)) != 0 }
            set { SERCOM0.SPI.intenset = (SERCOM0.SPI.intenset & ~(1 << 2)) | (newValue ? 1 << 2 : 0) }
        }
        
        /// SSL: Slave Select Low Interrupt Enable
        @inlinable @inline(__always)
        static var intensetSSL: Bool {
            get { (SERCOM0.SPI.intenset & (1 << 3)) != 0 }
            set { SERCOM0.SPI.intenset = (SERCOM0.SPI.intenset & ~(1 << 3)) | (newValue ? 1 << 3 : 0) }
        }
        
        /// ERROR: Combined Error Interrupt Enable
        @inlinable @inline(__always)
        static var intensetERROR: Bool {
            get { (SERCOM0.SPI.intenset & (1 << 7)) != 0 }
            set { SERCOM0.SPI.intenset = (SERCOM0.SPI.intenset & ~(1 << 7)) | (newValue ? 1 << 7 : 0) }
        }
        
        // MARK: - INTFLAG
        
        /// SPI Interrupt Flag Status and Clear - INTFLAG
        /// DRE: Data Register Empty Interrupt
        /// TXC: Transmit Complete Interrupt
        /// RXC: Receive Complete Interrupt
        /// SSL: Slave Select Low Interrupt Flag
        /// ERROR: Combined Error Interrupt
        ///
        /// W1C: writing 1 to a flag bit clears it; writing 0 has no effect.
        /// The setter writes the byte directly (no read-modify-write) so it
        /// does not accidentally clear other set flags or the BUFOVF bit in
        /// the upper half-word (STATUS).
        @inline(__always)
        static var intflag: UInt32 {
            get {
                (_volatileRegisterReadUInt32(SERCOM0_BASE + 0x18) >> 0) & 0x000000FF
            }
            set {
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, (newValue & 0xFF) << 0)
            }
        }

        /// DRE: Data Register Empty Interrupt (W1C)
        @inlinable @inline(__always)
        static var intflagDRE: Bool {
            get { (SERCOM0.SPI.intflag & (1 << 0)) != 0 }
            set { if newValue { _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, 1 << 0) } }
        }

        /// TXC: Transmit Complete Interrupt (W1C)
        @inlinable @inline(__always)
        static var intflagTXC: Bool {
            get { (SERCOM0.SPI.intflag & (1 << 1)) != 0 }
            set { if newValue { _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, 1 << 1) } }
        }

        /// RXC: Receive Complete Interrupt (W1C)
        @inlinable @inline(__always)
        static var intflagRXC: Bool {
            get { (SERCOM0.SPI.intflag & (1 << 2)) != 0 }
            set { if newValue { _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, 1 << 2) } }
        }

        /// SSL: Slave Select Low Interrupt Flag (W1C)
        @inlinable @inline(__always)
        static var intflagSSL: Bool {
            get { (SERCOM0.SPI.intflag & (1 << 3)) != 0 }
            set { if newValue { _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, 1 << 3) } }
        }

        /// ERROR: Combined Error Interrupt (W1C)
        @inlinable @inline(__always)
        static var intflagERROR: Bool {
            get { (SERCOM0.SPI.intflag & (1 << 7)) != 0 }
            set { if newValue { _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, 1 << 7) } }
        }
        
        // Compatibility aliases (DRE/TXC/RXC spellings used by SPI0).
        @inlinable @inline(__always) static var intFlagDRE: Bool { intflagDRE }
        @inlinable @inline(__always) static var intFlagTXC: Bool { intflagTXC }
        @inlinable @inline(__always) static var intFlagRXC: Bool { intflagRXC }
        
        // MARK: - STATUS
        
        /// SPI Status - STATUS
        /// BUFOVF: Buffer Overflow
        ///
        /// BUFOVF is W1C. Setter writes the half-word directly into bits
        /// [31:16] without preserving the lower 16 bits (INTFLAG), so that a
        /// previously-set INTFLAG bit is not accidentally cleared as a side
        /// effect of writing STATUS.
        @inline(__always)
        static var status: UInt32 {
            get {
                (_volatileRegisterReadUInt32(SERCOM0_BASE + 0x18) >> 16) & 0x0000FFFF
            }
            set {
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, (newValue & 0xFFFF) << 16)
            }
        }

        /// BUFOVF: Buffer Overflow (W1C)
        @inlinable @inline(__always)
        static var bufovf: Bool {
            get { (SERCOM0.SPI.status & (1 << 2)) != 0 }
            set { if newValue { _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x18, 1 << 18) } }
        }
        
        // MARK: - SYNCBUSY
        
        /// SPI Syncbusy - SYNCBUSY
        /// SWRST: Software Reset Synchronization Busy
        /// ENABLE: SERCOM Enable Synchronization Busy
        /// CTRLB: CTRLB Synchronization Busy
        @inline(__always)
        static var syncbusy: UInt32 {
            get {
                _volatileRegisterReadUInt32(SERCOM0_BASE + 0x1C)
            }
        }
        
        /// SWRST: Software Reset Synchronization Busy
        @inlinable @inline(__always)
        static var syncbusySWRST: Bool {
            get { (SERCOM0.SPI.syncbusy & (1 << 0)) != 0 }
        }
        
        /// ENABLE: SERCOM Enable Synchronization Busy
        @inlinable @inline(__always)
        static var syncbusyEnable: Bool {
            get { (SERCOM0.SPI.syncbusy & (1 << 1)) != 0 }
        }
        
        /// CTRLB: CTRLB Synchronization Busy
        @inlinable @inline(__always)
        static var syncbusyCTRLB: Bool {
            get { (SERCOM0.SPI.syncbusy & (1 << 2)) != 0 }
        }
        
        // MARK: - ADDR
        
        /// SPI Address - ADDR
        /// ADDR: Address Value
        /// ADDRMASK: Address Mask
        @inline(__always)
        static var addrRegister: UInt32 {
            get {
                _volatileRegisterReadUInt32(SERCOM0_BASE + 0x24)
            }
            set {
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x24, newValue)
            }
        }
        
        /// ADDR: Address Value
        @inlinable @inline(__always)
        static var addr: UInt32 {
            get { SERCOM0.SPI.addrRegister & 0xFF }
            set { SERCOM0.SPI.addrRegister = (SERCOM0.SPI.addrRegister & ~UInt32(0xFF)) | (newValue & 0xFF) }
        }
        
        /// ADDRMASK: Address Mask
        @inlinable @inline(__always)
        static var addrmask: UInt32 {
            get { (SERCOM0.SPI.addrRegister >> 16) & 0xFF }
            set { SERCOM0.SPI.addrRegister = (SERCOM0.SPI.addrRegister & ~UInt32(0x00FF0000)) | ((newValue & 0xFF) << 16) }
        }
        
        // MARK: - DATA

        /// SPI Data - DATA
        /// DATA: Data Value
        /// Single-field register; data var is the 9-bit DATA field directly.
        @inline(__always)
        static var data: UInt32 {
            get {
                _volatileRegisterReadUInt32(SERCOM0_BASE + 0x28)
            }
            set {
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x28, newValue)
            }
        }
        
        
        // MARK: - DBGCTRL
        
        /// SPI Debug Control - DBGCTRL
        /// DBGSTOP: Debug Mode
        @inline(__always)
        static var dbgctrl: UInt32 {
            get {
                (_volatileRegisterReadUInt32(SERCOM0_BASE + 0x30) >> 0) & 0x000000FF
            }
            set {
                let word = _volatileRegisterReadUInt32(SERCOM0_BASE + 0x30)
                _volatileRegisterWriteUInt32(SERCOM0_BASE + 0x30, (word & 0xFFFFFF00) | ((newValue & 0xFF) << 0))
            }
        }
        
        /// DBGSTOP: Debug Mode
        @inlinable @inline(__always)
        static var dbgstop: Bool {
            get { (SERCOM0.SPI.dbgctrl & (1 << 0)) != 0 }
            set { SERCOM0.SPI.dbgctrl = (SERCOM0.SPI.dbgctrl & ~(1 << 0)) | (newValue ? 1 << 0 : 0) }
        }
    }
}
