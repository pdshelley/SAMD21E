//===----------------------------------------------------------------------===//
//
// Port.swift
// Swift For Arduino
//
// Created by Carl Peto & Paul Shelley on 11/27/20.
// Copyright © 2020 Swift4Arduino. All rights reserved.
//
//===----------------------------------------------------------------------===//


// NOTE: This Port abstraction could also have the same issue. I think it's very safe to assume that all of the AVR chips will work this way but I am unfamiliar with how strong this convention is. I'll try to research this.
// See ATmega48A/PA/88A/PA/168A/PA/328/P Datasheet section 14
protocol PartialPort {
    associatedtype PortType: BinaryInteger
    static var dataRegister: PortType { get set }
    static var inputAddress: PortType { get } // TODO: Can you write to this? See 14.4.4
}

// we separate out the PartialPort protocol because some AVR chips (the HVA series) have
// a port that only contains read/write registers and no data direction register
protocol Port: PartialPort {
    static var dataDirection: PortType { get set }
}

protocol Bit {
    associatedtype BitType: BinaryInteger
    associatedtype PinMaskType: BinaryInteger
    static var bit: BitType { get }
}

extension Bit {
    @inline(__always)
    static var pinSetMask: PinMaskType {
        1 << bit
    }

    @inline(__always)
    static var pinClearMask: PinMaskType {
        ~(1 << bit)
    }

    @inline(__always)
    static var pinDirectionSetMask: PinMaskType {
        1 << bit
    }

    @inline(__always)
    static var pinDirectionClearMask: PinMaskType {
        ~(1 << bit)
    }

    @inline(__always)
    static var pinGetMask: PinMaskType {
        1 << bit
    }
}

protocol PartialPortPin {
    associatedtype PinPartialPort: PartialPort
    associatedtype PinBit: Bit

    static func setValue(_ value: DigitalValue)
    static func value() -> DigitalValue
}

enum DataDirectionFlag: UInt32 {
    case input, output
}

protocol PortPin: PartialPortPin where PinPartialPort == PinPort {
    associatedtype PinPort: Port
    static func setDataDirection(_ direction: DataDirectionFlag)
}

// TODO: I would love to extend pins with additionl functionality that have it. Obvious cases are Digial pins, pins with Analouge to Digital capabilities, and Pulse Width Moduation capabilities.
// Carl: But, the danger is (as with Arduino Wiring library) you hide the fact you're actually using a timer. Maybe it's better to keep the config on the timer. And doing something like timer2... mode fast pwm... output on pin pd3... Mark 50%

//protocol Digital: Pin {
//
//}
//
//protocol ADC: Pin { // Note: Should we use the word `Analogue` here or should we call this something else more inline with the datasheet like ADC? I'm leaning to ADC
//
//}
//
//protocol PWM: Pin {
//
//}

extension PartialPortPin where PinPartialPort.PortType == PinBit.PinMaskType {
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
    if value == .high {
      PinPartialPort.dataRegister |= PinBit.pinSetMask
    } else {
      PinPartialPort.dataRegister &= PinBit.pinClearMask
    }
  }

    @inline(__always)
    static func value() -> DigitalValue {
      return DigitalValue(PinPartialPort.inputAddress & PinBit.pinGetMask != 0)
  }
}

extension PortPin where PinPort.PortType == PinBit.PinMaskType {
//    @inline(__always)
    static func setDataDirection(_ direction: DataDirectionFlag) {
        switch direction {
            case .input:
                PinPort.dataDirection &= PinBit.pinDirectionClearMask
            case .output:
                PinPort.dataDirection |= PinBit.pinDirectionSetMask
        }
    }
}

// Ports that expose dedicated set/clear registers (e.g. SAMD21 DIRSET/DIRCLR, OUTSET/OUTCLR).
// Conforming types get overriding implementations that avoid read-modify-write.
protocol AtomicPort: Port {
    static var dataDirectionSet: PortType { get set }
    static var dataDirectionClear: PortType { get set }
    static var dataRegisterSet: PortType { get set }
    static var dataRegisterClear: PortType { get set }
}

extension PortPin where PinPort: AtomicPort, PinPort.PortType == PinBit.PinMaskType {
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
        if value == .high {
            PinPort.dataRegisterSet = PinBit.pinSetMask
        } else {
            PinPort.dataRegisterClear = PinBit.pinSetMask
        }
    }

//    @inline(__always)
    static func setDataDirection(_ direction: DataDirectionFlag) {
        switch direction {
        case .input:  PinPort.dataDirectionClear = PinBit.pinSetMask
        case .output: PinPort.dataDirectionSet   = PinBit.pinSetMask
        }
    }
}

enum DigitalPin<_Port: Port, _Bit: Bit>: PortPin where _Port.PortType == _Bit.PinMaskType {
    typealias PinPort = _Port
    typealias PinPartialPort = _Port
    typealias PinBit = _Bit
}

extension DigitalPin where PinPort == GPIO.PORTA {
    /// Set the peripheral multiplexing function for this pin.
    /// Usage: GPIO.PA09.setPeripheralMux(.c)
//    @inline(__always)
    static func setPeripheralMux(_ function: PeripheralFunction) {
        GPIO.PORTA.setPeripheralMux(pin: UInt32(truncatingIfNeeded: PinBit.bit), function: function)
    }

    /// PINCFG.PMUXEN — route pin to peripheral function.
    static func setPeripheralMuxEnable(enabled: Bool) {
        GPIO.PORTA.setPeripheralMuxEnable(
            pin: UInt32(truncatingIfNeeded: PinBit.bit),
            enabled: enabled
        )
    }

    /// PINCFG.INEN — input synchronizer (e.g. SPI MISO).
    static func setInputEnable(enabled: Bool) {
        GPIO.PORTA.setInputEnable(
            pin: UInt32(truncatingIfNeeded: PinBit.bit),
            enabled: enabled
        )
    }
}

enum InputOnlyDigitalPin<_Port: PartialPort, _Bit: Bit>: PartialPortPin where _Port.PortType == _Bit.PinMaskType {
    typealias PinPartialPort = _Port
    typealias PinBit = _Bit
}

// bit definitions for AVR
enum Bit0: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 0 }
}

enum Bit1: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 1 }
}

enum Bit2: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 2 }
}

enum Bit3: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 3 }
}

enum Bit4: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 4 }
}

enum Bit5: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 5 }
}

enum Bit6: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 6 }
}

enum Bit7: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 7 }
}

enum Bit8: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 8 }
}

enum Bit9: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 9 }
}

enum Bit10: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 10 }
}

enum Bit11: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 11 }
}

enum Bit12: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 12 }
}

enum Bit13: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 13 }
}

enum Bit14: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 14 }
}

enum Bit15: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 15 }
}

enum Bit16: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 16 }
}

enum Bit17: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 17 }
}

enum Bit18: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 18 }
}

enum Bit19: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 19 }
}

enum Bit20: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 20 }
}

enum Bit21: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 21 }
}

enum Bit22: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 22 }
}

enum Bit23: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 23 }
}

enum Bit24: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 24 }
}

enum Bit25: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 25 }
}

enum Bit26: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 26 }
}

enum Bit27: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 27 }
}

enum Bit28: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 28 }
}

enum Bit29: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 29 }
}

enum Bit30: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 30 }
}

enum Bit31: Bit {
    typealias PinMaskType = UInt32

    @inline(__always)
    static var bit: UInt32 { 31 }
}



//------------------------------------------------------------------------------
// Get a single bit from an 32 bit register (value)

@inline(__always)

func getRegisterBit(_ register: UInt32, bit: UInt32) -> Bool {

//    let registerValue: UInt32 = _volatileRegisterReadUInt32(UInt16(register))
//    let bitFilter = 1 << bit
//    let filtered = registerValue & bitFilter
//    return filtered != 0
    return false
}

//------------------------------------------------------------------------------
// Set a single bit in an 8 bit register, leaving all other bits intact

@inline(__always)

func setRegisterBit(_ register: UInt32, bit: UInt32, value: Bool) {

//    let bitFilter = 1 << bit

    // Clear bit of interest, leave rest alone
//    var result = register & ~bitFilter

    // Set bit of interest (if needed)
    if value {
//        result = result | bitFilter
    }

//    _volatileRegisterWriteUInt32(UInt16(register), result)
}

//------------------------------------------------------------------------------
