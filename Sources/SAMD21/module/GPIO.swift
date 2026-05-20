//
//  GPIO.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/18/26.
//


@usableFromInline let PORTA_BASE: UInt = 0x41004400   // SAMD21 datasheet §23.8

/// Peripheral multiplexing function (PMUX) — see SAMD21 datasheet 6.1 and 23.8.12
enum PeripheralFunction: UInt8 {
    case a = 0
    case b = 1
    case c = 2   // SERCOM on QT Py (PA08–PA11)
    case d = 3
    case e = 4
    case f = 5
    case g = 6
    case h = 7
}


struct GPIO {
    
    struct PORTA: AtomicPort {
        
        /// Data Direction - DIR
        /// See Section 23.8.1.
        ///
        /// This register allows the user to configure one or more I/O pins as an input or output. This register
        /// can be manipulated without doing a read-modify-write operation by using the Data Direction Toggle
        /// (DIRTGL), Data Direction Clear (DIRCLR) and Data Direction Set (DIRSET) registers.
        ///
        /// Bits 31:0
        /// These bits set the data direction for the individual I/O pins in the PORT group.
        /// ```
        /// -----------------------------------------------------------------------------------
        /// | Value | Description                                                             |
        /// -----------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the PORT group is configured as an input.  |
        /// -----------------------------------------------------------------------------------
        /// | 1     | The corresponding I/O pin in the PORT group is configured as an output. |
        /// -----------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataDirection: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE, newValue)
            }
        }
        
        /// Data Direction Clear - DIRCLR
        /// See Section 23.8.2.
        ///
        /// This register allows the user to set one or more I/O pins as an input, without doing a read-modify-
        /// write operation. Changes in this register will also be reflected in the Data Direction (DIR), Data
        /// Direction Toggle (DIRTGL) and Data Direction Set (DIRSET) registers.
        ///
        /// Bits 31:0
        /// Writing a '0' to a bit has no effect.
        /// Writing a '1' to a bit will clear the corresponding bit in the DIR register, which configures the I/O pin as an input.
        /// ```
        /// ------------------------------------------------------------------------------------
        /// | Value | Description                                                              |
        /// ------------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the PORT group will keep its configuration. |
        /// ------------------------------------------------------------------------------------
        /// | 1     | The corresponding I/O pin in the PORT group is configured as input.      |
        /// ------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataDirectionClear: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x04)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x04, newValue)
            }
        }
        
        /// Data Direction Set - DIRSET
        /// See Section 23.8.3.
        ///
        /// This register allows the user to set one or more I/O pins as an output, without doing a read-modify-
        /// write operation. Changes in this register will also be reflected in the Data Direction (DIR), Data
        /// Direction Toggle (DIRTGL) and Data Direction Clear (DIRCLR) registers.
        ///
        /// Bits 31:0
        /// Writing a '0' to a bit has no effect.
        /// Writing '1' to a bit will set the corresponding bit in the DIR register, which configures the I/O pin as an output.
        /// ```
        /// ------------------------------------------------------------------------------------
        /// | Value | Description                                                              |
        /// ------------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the PORT group will keep its configuration. |
        /// ------------------------------------------------------------------------------------
        /// | 1     | The corresponding I/O pin in the PORT group is configured as an output.  |
        /// ------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataDirectionSet: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x08)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x08, newValue)
            }
        }
        
        /// Data Direction Toggle - DIRTGL
        /// See Section 23.8.4.
        ///
        /// This register allows the user to toggle the direction of one or more I/O pins, without doing a
        /// read-modify-write operation. Changes in this register will also be reflected in the Data Direction
        /// (DIR), Data Direction Set (DIRSET) and Data Direction Clear (DIRCLR) registers.
        ///
        /// Bits 31:0
        /// Writing a '0' to a bit has no effect.
        /// Writing '1' to a bit will toggle the corresponding bit in the DIR register, which reverses the direction of the I/O pin.
        /// ```
        /// ------------------------------------------------------------------------------------
        /// | Value | Description                                                              |
        /// ------------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the PORT group will keep its configuration. |
        /// ------------------------------------------------------------------------------------
        /// | 1     | The direction of the corresponding I/O pin is toggled.                   |
        /// ------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataDirectionToggle: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x0C)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x0C, newValue)
            }
        }
        
        // TODO: Better universal naming to fit with the 8 bit versions?
        /// Data Register (Data Output Value) - OUT
        /// See Section 23.8.5.
        ///
        /// This register sets the data output drive value for the individual I/O pins in the PORT.
        /// This register can be manipulated without doing a read-modify-write operation by using the Data
        /// Output Value Clear (OUTCLR), Data Output Value Set (OUTSET), and Data Output Value Toggle
        /// (OUTTGL) registers.
        ///
        /// Bits 31:0
        /// For pins configured as outputs via the Data Direction register (DIR), these bits set the logical output drive level.
        /// For pins configured as inputs via the Data Direction register (DIR) and with pull enabled via the Pull Enable bit in
        /// the Pin Configuration register (PINCFG.PULLEN), these bits will set the input pull direction.
        /// ```
        /// -------------------------------------------------------------------------------------------------
        /// | Value | Description                                                                           |
        /// -------------------------------------------------------------------------------------------------
        /// | 0     | The I/O pin output is driven low, or the input is connected to an internal pull-down. |
        /// -------------------------------------------------------------------------------------------------
        /// | 1     | The I/O pin output is driven high, or the input is connected to an internal pull-up.  |
        /// -------------------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataRegister: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x10)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x10, newValue)
            }
        }
        
        // TODO: Better universal naming to fit with the 8 bit versions?
        /// Data Output Value Clear - OUTCLR
        /// See Section 23.8.6.
        ///
        /// This register allows the user to set one or more output I/O pin drive levels low, without doing a
        /// read-modify-write operation. Changes in this register will also be reflected in the Data Output Value
        /// (OUT), Data Output Value Toggle (OUTTGL) and Data Output Value Set (OUTSET) registers.
        ///
        /// Bits 31:0
        /// Writing '0' to a bit has no effect.
        /// Writing '1' to a bit will clear the corresponding bit in the OUT register. Pins configured as outputs via
        /// the Data Direction register (DIR) will be set to low output drive level. Pins configured as inputs via
        /// DIR and with pull enabled via the Pull Enable bit in the Pin Configuration register (PINCFG.PULLEN)
        /// will set the input pull direction to an internal pull-down.
        /// ```
        /// ---------------------------------------------------------------------------------------------------------------
        /// | Value | Description                                                                                         |
        /// ---------------------------------------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the PORT group will keep its configuration.                            |
        /// ---------------------------------------------------------------------------------------------------------------
        /// | 1     | The corresponding I/O pin output is driven low, or the input is connected to an internal pull-down. |
        /// ---------------------------------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataRegisterClear: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x14)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x14, newValue)
            }
        }
        
        // TODO: Better universal naming to fit with the 8 bit versions?
        /// Data Output Value Set - OUTSET
        /// See Section 23.8.7.
        ///
        /// This register allows the user to set one or more output I/O pin drive levels high, without doing a
        /// read-modify-write operation. Changes in this register will also be reflected in the Data Output Value
        /// (OUT), Data Output Value Toggle (OUTTGL) and Data Output Value Clear (OUTCLR) registers.
        ///
        /// Bits 31:0
        /// Writing '0' to a bit has no effect.
        /// Writing '1' to a bit will set the corresponding bit in the OUT register, which sets the output drive level
        /// high for I/O pins configured as outputs via the Data Direction register (DIR). For pins configured as
        /// inputs via Data Direction register (DIR) with pull enabled via the Pull Enable register (PULLEN), these
        /// bits will set the input pull direction to an internal pull-up.
        /// ```
        /// --------------------------------------------------------------------------------------------------------------
        /// | Value | Description                                                                                        |
        /// --------------------------------------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the group will keep its configuration.                                |
        /// --------------------------------------------------------------------------------------------------------------
        /// | 1     | The corresponding I/O pin output is driven high, or the input is connected to an internal pull-up. |
        /// --------------------------------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataRegisterSet: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x18)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x18, newValue)
            }
        }
        
        /// Data Output Value Toggle - OUTTGL
        /// See Section 23.8.8.
        ///
        /// This register allows the user to toggle the drive level of one or more output I/O pins, without doing a
        /// read-modify-write operation. Changes in this register will also be reflected in the Data Output Value
        /// (OUT), Data Output Value Set (OUTSET) and Data Output Value Clear (OUTCLR) registers.
        ///
        /// Bits 31:0
        /// Writing '0' to a bit has no effect.
        /// Writing '1' to a bit will toggle the corresponding bit in the OUT register, which inverts the output
        /// drive level for I/O pins configured as outputs via the Data Direction register (DIR). For pins
        /// configured as inputs via Data Direction register (DIR) with pull enabled via the Pull Enable register
        /// (PULLEN), these bits will toggle the input pull direction.
        /// ```
        /// ------------------------------------------------------------------------------------
        /// | Value | Description                                                              |
        /// ------------------------------------------------------------------------------------
        /// | 0     | The corresponding I/O pin in the PORT group will keep its configuration. |
        /// ------------------------------------------------------------------------------------
        /// | 1     | The corresponding OUT bit value is toggled.                              |
        /// ------------------------------------------------------------------------------------
        /// ```
//        @inline(__always)
        static var dataOutputValueToggle: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x1C)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x1C, newValue)
            }
        }
        
        // TODO: Better universal naming to fit with the 8 bit versions?
        /// Input Address (Data Input Value) - IN
        /// See Section 23.8.9.
        ///
        /// Bits 31:0
        /// These bits are cleared when the corresponding I/O pin input sampler detects a logical low level on
        /// the input pin.
        /// These bits are set when the corresponding I/O pin input sampler detects a logical high level on the
        /// input pin.
//        @inline(__always)
        static var inputAddress: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x20)
            }
        }
        
        /// Input Sampling Mode - Control - CTRL
        /// See Section 23.8.10.
        ///
        /// Bits 31:0 – SAMPLING[31:0] Input Sampling Mode
        /// Configures the input sampling functionality of the I/O pin input samplers, for pins configured as
        /// inputs via the Data Direction register (DIR).
        /// The input samplers are enabled and disabled in sub-groups of eight. Thus if any pins within a byte
        /// request continuous sampling, all pins in that eight pin sub-group will be continuously sampled.
        /// ```
        /// ------------------------------------------------------
        /// | Value | Description                                |
        /// ------------------------------------------------------
        /// | 0     | On demand sampling of I/O pin is enabled.  |
        /// ------------------------------------------------------
        /// | 1     | Continuous sampling of I/O pin is enabled. |
        /// ------------------------------------------------------
        /// ```
//        @inline(__always)
        static var inputSamplingMode: UInt32 {
            get {
                _volatileRegisterReadUInt32(PORTA_BASE + 0x24)
            }
            set {
                _volatileRegisterWriteUInt32(PORTA_BASE + 0x24, newValue)
            }
        }
        
        /// WRCONFIG
        
        
        /// PMUX0 –  Peripheral Multiplexing n - 23.8.12.
        ///
        /// Name: PMUX
        /// Offset: 0x30 + n*0x01 [n=0..15]
        /// Reset: 0x00
        /// Property: PAC Write-Protection
        ///
        /// Tip: The I/O pins are assembled in pin groups (”PORT groups”) with up to 32 pins.
        /// Group 0 consists of the PA pins, group 1 is for the PB pins, etc. Each pin group
        /// has its own PORT registers, with a 0x80 address spacing. For example, the register
        /// address offset for the Data Direction (DIR) register for group 0 (PA00 to PA31) is
        /// 0x00, and the register address offset for the DIR register for group 1 (PB00 to
        /// PB31) is 0x80.
        ///
        /// There are up to 16 Peripheral Multiplexing registers in each group, one for every set of two
        /// subsequent I/O lines. The n denotes the number of the set of I/O lines.
        /// ```
        /// --------------------------------------------------------------------------------
        /// | Bit          |   7   |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
        /// --------------------------------------------------------------------------------
        /// |              |             PMUXO             |             PMUXE             |
        /// --------------------------------------------------------------------------------
        /// | Read/Write   |  R/W  |  R/W  |  R/W  |  R/W  |  R/W  |  R/W  |  R/W  |  R/W  |
        /// --------------------------------------------------------------------------------
        /// | Reset        |   0   |   0   |   0   |   0   |   0   |   0   |   0   |   0   |
        /// --------------------------------------------------------------------------------
        /// ```
        /// This causes problems when it is inlined. Leave as is.
        static func setPeripheralMux(pin: UInt32, function: PeripheralFunction) {
            let index = UInt(pin / 2)
            let address = PORTA_BASE + 0x30 + index
            let current = readUInt8(address)

            if (pin & 1) == 0 {
                // even pin → low nibble
                let value = (current & 0xF0) | function.rawValue
                writeUInt8(address, value)
            } else {
                // odd pin → high nibble
                let value = (current & 0x0F) | (function.rawValue << 4)
                writeUInt8(address, value)
            }
        }
        
        /// PMUX15
        
        /// PINCFG0
        
        /// PINCFG31
        
        
        
        
        /// Configure a pin for peripheral use (e.g. SERCOM PAD) in the minimal number of writes.
        ///
        /// - PMUX function is set
        /// - PMUXEN = 1 and INEN (if requested) are set in **one** PINCFG write
        /// - No extra RMW storms
        ///
        /// This is the safe, efficient replacement for the old three-call pattern.
//        @inlinable @inline(__always)
        static func configureForPeripheral(pin: UInt32, function: PeripheralFunction, inputEnable: Bool = false) {
            // 1. Set the peripheral function (PMUX register)
            setPeripheralMux(pin: pin, function: function)

            // 2. Single atomic write to PINCFG byte (PMUXEN + INEN)
            let address = PORTA_BASE + 0x40 + UInt(pin)
            var cfg: UInt8 = 0x01                    // PMUXEN = 1
            if inputEnable {
                cfg |= 0x02                          // INEN = 1
            }
            writeUInt8(address, cfg)
        }

        /// 23.8.13. Pin Configuration n (PINCFG)
        /// PINCFG.PMUXEN (bit 0): route the pin to its peripheral function.
        ///
        // @inline(__always) /// This causes problems when it is inlined. Leave as is.
        static func setPeripheralMuxEnable(pin: UInt32, enabled: Bool) {
            let address = PORTA_BASE + 0x40 + UInt(pin)
            let current = readUInt8(address)
            let value = enabled ? (current | 0x01) : (current & 0xFE)
            writeUInt8(address, value)
        }

        /// PINCFG.INEN (bit 1): enable the input synchronizer/sampler.
        /// Required for any peripheral input (e.g. SPI MISO); has no effect
        /// when the pin is driven as an output.
        /// This causes problems when it is inlined. Leave as is.
        static func setInputEnable(pin: UInt32, enabled: Bool) {
            let address = PORTA_BASE + 0x40 + UInt(pin)
            let current = readUInt8(address)
            let value = enabled ? (current | 0x02) : (current & 0xFD)
            writeUInt8(address, value)
        }

        @inline(__always) // Needed
        private static func readUInt8(_ address: UInt) -> UInt8 {
            let alignedAddress = address & ~UInt(0x03)
            let shift = UInt32((address & 0x03) * 8)
            let word = _volatileRegisterReadUInt32(alignedAddress)
            return UInt8((word >> shift) & 0xFF)
        }

        @inline(__always) // I think Needed
        private static func writeUInt8(_ address: UInt, _ value: UInt8) {
            let alignedAddress = address & ~UInt(0x03)
            let shift = UInt32((address & 0x03) * 8)
            let mask = UInt32(0xFF) << shift
            let current = _volatileRegisterReadUInt32(alignedAddress)
            let updated = (current & ~mask) | (UInt32(value) << shift)
            _volatileRegisterWriteUInt32(alignedAddress, updated)
        }
    }
    
    /// PORTA
    typealias PA00 = DigitalPin<PORTA, Bit0>
    typealias PA01 = DigitalPin<PORTA, Bit1>
    typealias PA02 = DigitalPin<PORTA, Bit2>
    typealias PA03 = DigitalPin<PORTA, Bit3>
    typealias PA04 = DigitalPin<PORTA, Bit4>
    typealias PA05 = DigitalPin<PORTA, Bit5>
    typealias PA06 = DigitalPin<PORTA, Bit6>
    typealias PA07 = DigitalPin<PORTA, Bit7>
    typealias PA08 = DigitalPin<PORTA, Bit8>
    typealias PA09 = DigitalPin<PORTA, Bit9>
    typealias PA10 = DigitalPin<PORTA, Bit10>
    typealias PA11 = DigitalPin<PORTA, Bit11>
    typealias PA12 = DigitalPin<PORTA, Bit12>
    typealias PA13 = DigitalPin<PORTA, Bit13>
    typealias PA14 = DigitalPin<PORTA, Bit14>
    typealias PA15 = DigitalPin<PORTA, Bit15>
    typealias PA16 = DigitalPin<PORTA, Bit16>
    typealias PA17 = DigitalPin<PORTA, Bit17>
    typealias PA18 = DigitalPin<PORTA, Bit18>
    typealias PA19 = DigitalPin<PORTA, Bit19>
    typealias PA20 = DigitalPin<PORTA, Bit20>
    typealias PA21 = DigitalPin<PORTA, Bit21>
    typealias PA22 = DigitalPin<PORTA, Bit22>
    typealias PA23 = DigitalPin<PORTA, Bit23>
    typealias PA24 = DigitalPin<PORTA, Bit24>
    typealias PA25 = DigitalPin<PORTA, Bit25>
    typealias PA26 = DigitalPin<PORTA, Bit26>
    typealias PA27 = DigitalPin<PORTA, Bit27>
    typealias PA28 = DigitalPin<PORTA, Bit28>
    typealias PA29 = DigitalPin<PORTA, Bit29>
    typealias PA30 = DigitalPin<PORTA, Bit30>
    typealias PA31 = DigitalPin<PORTA, Bit31>
}
