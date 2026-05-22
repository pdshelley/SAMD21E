//
//  Port.swift — minimal pin/port abstractions for GPIO hard-fault repro.
//

protocol PartialPort {
    associatedtype PortType: BinaryInteger
    static var dataRegister: PortType { get set }
}

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
    static var pinSetMask: PinMaskType { 1 << bit }

    @inline(__always)
    static var pinClearMask: PinMaskType { ~(1 << bit) }

    @inline(__always)
    static var pinDirectionSetMask: PinMaskType { 1 << bit }
}

enum DataDirectionFlag: UInt32 {
    case input, output
}

protocol PortPin: PartialPortPin where PinPartialPort == PinPort {
    associatedtype PinPort: Port
    static func setDataDirection(_ direction: DataDirectionFlag)
}

protocol PartialPortPin {
    associatedtype PinPartialPort: PartialPort
    associatedtype PinBit: Bit
    static func setValue(_ value: DigitalValue)
}

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

    static func setDataDirection(_ direction: DataDirectionFlag) {
        switch direction {
        case .input:  PinPort.dataDirectionClear = PinBit.pinSetMask
        case .output: PinPort.dataDirectionSet   = PinBit.pinSetMask
        }
    }
}

enum DigitalPin<_Port: AtomicPort, _Bit: Bit>: PortPin where _Port.PortType == _Bit.PinMaskType {
    typealias PinPort = _Port
    typealias PinPartialPort = _Port
    typealias PinBit = _Bit
}

enum Bit2: Bit {
    typealias PinMaskType = UInt32
    @inline(__always)
    static var bit: UInt32 { 2 }
}

enum Bit9: Bit {
    typealias PinMaskType = UInt32
    @inline(__always)
    static var bit: UInt32 { 9 }
}
