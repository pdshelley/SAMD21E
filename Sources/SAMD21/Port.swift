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
public protocol PartialPort {
    associatedtype PortType: BinaryInteger
    static var dataRegister: PortType { get set }
    static var inputAddress: PortType { get } // TODO: Can you write to this? See 14.4.4
}

// we separate out the PartialPort protocol because some AVR chips (the HVA series) have
// a port that only contains read/write registers and no data direction register
public protocol Port: PartialPort {
    static var dataDirection: PortType { get set }
}

public protocol Bit {
    associatedtype BitType: BinaryInteger
    associatedtype PinMaskType: BinaryInteger
    static var bit: BitType { get }
}

public extension Bit {
    @inlinable
    @inline(__always)
    static var pinSetMask: PinMaskType {
        1 << bit
    }

    @inlinable
    @inline(__always)
    static var pinClearMask: PinMaskType {
        ~(1 << bit)
    }

    @inlinable
    @inline(__always)
    static var pinDirectionSetMask: PinMaskType {
        1 << bit
    }

    @inlinable
    @inline(__always)
    static var pinDirectionClearMask: PinMaskType {
        ~(1 << bit)
    }

    @inlinable
    @inline(__always)
    static var pinGetMask: PinMaskType {
        1 << bit
    }
}

public protocol PartialPortPin {
    associatedtype PinPartialPort: PartialPort
    associatedtype PinBit: Bit

    static func setValue(_ value: DigitalValue)
    static func value() -> DigitalValue
}

@frozen
public enum DataDirectionFlag: UInt32 {
    case input, output
}

public protocol PortPin: PartialPortPin where PinPartialPort == PinPort {
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

public extension PartialPortPin where PinPartialPort.PortType == PinBit.PinMaskType {
    @inlinable
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
    if value == .high {
      PinPartialPort.dataRegister |= PinBit.pinSetMask
    } else {
      PinPartialPort.dataRegister &= PinBit.pinClearMask
    }
  }

    @inlinable
    @inline(__always)
    static func value() -> DigitalValue {
      return DigitalValue(PinPartialPort.inputAddress & PinBit.pinGetMask != 0)
  }
}

public extension PortPin where PinPort.PortType == PinBit.PinMaskType {
    @inlinable
    @inline(__always)
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
public protocol AtomicPort: Port {
    static var dataDirectionSet: PortType { get set }
    static var dataDirectionClear: PortType { get set }
    static var dataRegisterSet: PortType { get set }
    static var dataRegisterClear: PortType { get set }
}

public extension PortPin where PinPort: AtomicPort, PinPort.PortType == PinBit.PinMaskType {
    @inlinable
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
        if value == .high {
            PinPort.dataRegisterSet = PinBit.pinSetMask
        } else {
            PinPort.dataRegisterClear = PinBit.pinSetMask
        }
    }

    @inlinable
    @inline(__always)
    static func setDataDirection(_ direction: DataDirectionFlag) {
        switch direction {
        case .input:  PinPort.dataDirectionClear = PinBit.pinSetMask
        case .output: PinPort.dataDirectionSet   = PinBit.pinSetMask
        }
    }
}

public enum DigitalPin<_Port: Port, _Bit: Bit>: PortPin where _Port.PortType == _Bit.PinMaskType {
    public typealias PinPort = _Port
    public typealias PinPartialPort = _Port
    public typealias PinBit = _Bit
}

public enum InputOnlyDigitalPin<_Port: PartialPort, _Bit: Bit>: PartialPortPin where _Port.PortType == _Bit.PinMaskType {
    public typealias PinPartialPort = _Port
    public typealias PinBit = _Bit
}

// bit definitions for AVR
public enum Bit0: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 0 }
}

public enum Bit1: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 1 }
}

public enum Bit2: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 2 }
}

public enum Bit3: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 3 }
}

public enum Bit4: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 4 }
}

public enum Bit5: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 5 }
}

public enum Bit6: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 6 }
}

public enum Bit7: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 7 }
}

public enum Bit8: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 8 }
}

public enum Bit9: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 9 }
}

public enum Bit10: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 10 }
}

public enum Bit11: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 11 }
}

public enum Bit12: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 12 }
}

public enum Bit13: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 13 }
}

public enum Bit14: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 14 }
}

public enum Bit15: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 15 }
}

public enum Bit16: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 16 }
}

public enum Bit17: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 17 }
}

public enum Bit18: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 18 }
}

public enum Bit19: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 19 }
}

public enum Bit20: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 20 }
}

public enum Bit21: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 21 }
}

public enum Bit22: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 22 }
}

public enum Bit23: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 23 }
}

public enum Bit24: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 24 }
}

public enum Bit25: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 25 }
}

public enum Bit26: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 26 }
}

public enum Bit27: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 27 }
}

public enum Bit28: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 28 }
}

public enum Bit29: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 29 }
}

public enum Bit30: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 30 }
}

public enum Bit31: Bit {
    public typealias PinMaskType = UInt32

    @inlinable
    @inline(__always)
    public static var bit: UInt32 { 31 }
}



//------------------------------------------------------------------------------
// Get a single bit from an 32 bit register (value)

@inlinable
@inline(__always)

public func getRegisterBit(_ register: UInt32, bit: UInt32) -> Bool {

//    let registerValue: UInt32 = _volatileRegisterReadUInt32(UInt16(register))
//    let bitFilter = 1 << bit
//    let filtered = registerValue & bitFilter
//    return filtered != 0
    return false
}

//------------------------------------------------------------------------------
// Set a single bit in an 8 bit register, leaving all other bits intact

@inlinable
@inline(__always)

public func setRegisterBit(_ register: UInt32, bit: UInt32, value: Bool) {

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
