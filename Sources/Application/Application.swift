// swift#89287 repro — comment out the PA09 line in appInit() to avoid hard fault.

@usableFromInline let PORTA_BASE: UInt = 0x41004400

struct DigitalValue {
    var on: Bool
    init(_ on: Bool) { self.on = on }
    static let high = DigitalValue(true)
    static let low = DigitalValue(false)
    mutating func toggle() { on = !on }
}

protocol AtomicPort {
    associatedtype PortType: BinaryInteger
    static var dataDirectionSet: PortType { get set }
    static var dataDirectionClear: PortType { get set }
    static var dataRegisterSet: PortType { get set }
    static var dataRegisterClear: PortType { get set }
}

protocol Bit {
    associatedtype PinMaskType: BinaryInteger
    static var bit: UInt32 { get }
}

extension Bit { static var pinSetMask: PinMaskType { 1 << bit } }

enum DataDirectionFlag { case output }

protocol PortPin {
    associatedtype PinPort: AtomicPort
    associatedtype PinBit: Bit
}

extension PortPin where PinPort.PortType == PinBit.PinMaskType {
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
        if value.on { PinPort.dataRegisterSet = PinBit.pinSetMask }
        else { PinPort.dataRegisterClear = PinBit.pinSetMask }
    }

    static func setDataDirection(_ direction: DataDirectionFlag) {
        PinPort.dataDirectionSet = PinBit.pinSetMask
    }
}

enum DigitalPin<_Port: AtomicPort, _Bit: Bit>: PortPin
    where _Port.PortType == _Bit.PinMaskType
{
    typealias PinPort = _Port
    typealias PinBit = _Bit
}

enum Bit2: Bit { typealias PinMaskType = UInt32; static var bit: UInt32 { 2 } }
enum Bit9: Bit { typealias PinMaskType = UInt32; static var bit: UInt32 { 9 } }

struct GPIO {
    struct PORTA: AtomicPort {
        static var dataDirectionSet: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x08) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x08, newValue) }
        }
        static var dataDirectionClear: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x04) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x04, newValue) }
        }
        static var dataRegisterSet: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x18) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x18, newValue) }
        }
        static var dataRegisterClear: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x14) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x14, newValue) }
        }
    }
    typealias PA02 = DigitalPin<PORTA, Bit2>
    typealias PA09 = DigitalPin<PORTA, Bit9>
}

var led = DigitalValue.low
var spin: UInt32 = 0

@_cdecl("app_init")
func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
//    GPIO.PA09.setDataDirection(.output)  // comment this line to avoid hard fault
//    GPIO.PA09.setValue(.low)
}

@_cdecl("app_main")
func appMain() {
    spin &+= 1
    if spin & 0x1FFFFF == 0 {
        led.toggle()
        GPIO.PA02.setValue(led)
    }
}
