//
//  GPIO.swift — minimal PORT A register access for hard-fault repro.
//

@usableFromInline let PORTA_BASE: UInt = 0x41004400

struct GPIO {

    struct PORTA: AtomicPort {
        static var dataDirection: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE, newValue) }
        }

        static var dataDirectionClear: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x04) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x04, newValue) }
        }

        static var dataDirectionSet: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x08) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x08, newValue) }
        }

        static var dataRegister: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x10) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x10, newValue) }
        }

        static var dataRegisterClear: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x14) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x14, newValue) }
        }

        static var dataRegisterSet: UInt32 {
            get { _volatileRegisterReadUInt32(PORTA_BASE + 0x18) }
            set { _volatileRegisterWriteUInt32(PORTA_BASE + 0x18, newValue) }
        }
    }

    typealias PA02 = DigitalPin<PORTA, Bit2>
    typealias PA09 = DigitalPin<PORTA, Bit9>
}
