//
//  I2C3.swift
//  SAMD21E
//
//  SERCOM3 I2C master on STEMMA QT (QT Py SAMD21):
//  PA16 — SDA (SERCOM3 PAD0, mux D)
//  PA17 — SCL (SERCOM3 PAD1, mux D)
//
//  Low-level SERCOM access is in i2c3_master.c (CMSIS).
//

enum I2C3 {

    /// 7-bit I2C address for Adafruit APDS9999 (see product 6461).
    static let apds9999Address: UInt8 = 0x52
    static let apds9999PartIDRegister: UInt8 = 0x06
    static let apds9999ExpectedPartID: UInt8 = 0xC2

    static var isReady: Bool { configureDone }

    private static var configureStep: Int = 0
    private static var configureDone: Bool = false

    /// Bring-up isolation: two probes + SERCOM status on CDC (no bus scan).
    private static let isolateProbeEmpty: UInt8 = 0x08
    private static let isolateProbeApds: UInt8 = 0x52

    // MARK: - Configure

    static func configure() -> Bool {
        if configureDone { return true }
        switch configureStep {
        case 0:
            PowerManager.portClockEnable = true
        case 1:
            i2c3_master_init()
        case 2:
            configureDone = true
            return true
        default:
            break
        }
        configureStep &+= 1
        return false
    }

    // MARK: - Isolate test (disable full scan until bus proven on LA)

    /// One-shot: status snapshot, probe 0x08, probe 0x52, status after each.
    static func runIsolateTest() {
        guard configureDone else { return }
        CDC.print("I2C isolate test:\r\n")
        printDebugLine(tag: "init ")
        runIsolateProbe(address: isolateProbeEmpty, preTag: "08 pre ", postTag: "08 post ", label: "0x08")
        runIsolateProbe(address: isolateProbeApds, preTag: "52 pre ", postTag: "52 post ", label: "0x52")
        CDC.print("I2C isolate done\r\n")
    }

    private static func runIsolateProbe(
        address: UInt8,
        preTag: StaticString,
        postTag: StaticString,
        label: StaticString
    ) {
        printDebugLine(tag: preTag)
        let ack = i2c3_master_probe(address)
        printDebugLine(tag: postTag)
        cdc_write(label.utf8Start, UInt32(label.utf8CodeUnitCount))
        if ack {
            CDC.print(" probe: ACK\r\n")
        } else {
            CDC.print(" probe: no ACK\r\n")
        }
    }

    private static func printDebugLine(tag: StaticString) {
        var en: UInt8 = 0
        var bus: UInt8 = 0
        var flags: UInt8 = 0
        var nack: UInt8 = 0
        i2c3_master_debug_snapshot(&en, &bus, &flags, &nack)
        cdc_write(tag.utf8Start, UInt32(tag.utf8CodeUnitCount))
        CDC.print(" st en=")
        printHexNibble(en)
        CDC.print(" bus=")
        printHexNibble(bus)
        CDC.print(" if=")
        printHexByte(flags)
        CDC.print(" nack=")
        printHexNibble(nack)
        CDC.print("\r\n")
    }

    private static func printHexNibble(_ value: UInt8) {
        var c = hexDigit(value)
        _ = withUnsafePointer(to: &c) { ptr in
            cdc_write(UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), 1)
        }
    }

    private static func printHexByte(_ value: UInt8) {
        var nibbles: (UInt8, UInt8) = (hexDigit(value >> 4), hexDigit(value & 0x0F))
        _ = withUnsafePointer(to: &nibbles) { ptr in
            cdc_write(UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), 2)
        }
    }

    static func probeAPDS9999() {
        var partID: UInt8 = 0
        if !i2c3_master_read_reg(apds9999Address, apds9999PartIDRegister, &partID) {
            CDC.print("APDS9999: read failed\r\n")
            return
        }
        if partID == apds9999ExpectedPartID {
            CDC.print("APDS9999: PART_ID OK (0xC2)\r\n")
        } else {
            CDC.print("APDS9999: unexpected PART_ID\r\n")
            printHexByteLine(prefix: "  got 0x", value: partID)
        }
    }

    // MARK: - Transactions

    static func probe(address: UInt8) -> Bool {
        guard configureDone else { return false }
        return i2c3_master_probe(address)
    }

    static func readRegister(_ address: UInt8, reg: UInt8) -> UInt8? {
        guard configureDone else { return nil }
        var value: UInt8 = 0
        guard i2c3_master_read_reg(address, reg, &value) else { return nil }
        return value
    }

    // MARK: - CDC helpers

    private static func printHexByteLine(prefix: StaticString, value: UInt8) {
        cdc_write(prefix.utf8Start, UInt32(prefix.utf8CodeUnitCount))
        var nibbles: (UInt8, UInt8) = (hexDigit(value >> 4), hexDigit(value & 0x0F))
        _ = withUnsafePointer(to: &nibbles) { ptr in
            cdc_write(UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), 2)
        }
        CDC.print("\r\n")
    }

    private static func hexDigit(_ nibble: UInt8) -> UInt8 {
        let n = nibble & 0x0F
        if n < 10 { return 0x30 + n }
        return 0x41 + (n - 10)
    }
}
