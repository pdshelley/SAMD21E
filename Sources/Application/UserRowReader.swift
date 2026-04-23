//
//  UserRowReader.swift
//  SAMD21E
//

struct UserRowReader {
    static let baseAddress: UInt = 0x0080_4000
    static let byteCount: Int = 64

    @inline(__always)
    static func loadWord() -> UInt32 {
        _volatileRegisterReadUInt32(baseAddress)
    }

    static func loadMACAddress() -> (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) {
        let word0 = _volatileRegisterReadUInt32(baseAddress)
        let word1 = _volatileRegisterReadUInt32(baseAddress + 4)

        let b0 = UInt8((word0 >> 0) & 0xFF)
        let b1 = UInt8((word0 >> 8) & 0xFF)
        let b2 = UInt8((word0 >> 16) & 0xFF)
        let b3 = UInt8((word0 >> 24) & 0xFF)
        let b4 = UInt8((word1 >> 0) & 0xFF)
        let b5 = UInt8((word1 >> 8) & 0xFF)

        return (b0, b1, b2, b3, b4, b5)
    }

//    static func readBytes() -> [UInt8] {
//        var bytes = [UInt8](repeating: 0, count: byteCount)
//        var offset = 0
//        while offset < byteCount {
//            let word = loadWord(address: baseAddress + UInt32(offset))
//            bytes[offset + 0] = UInt8((word >> 0) & 0xFF)
//            bytes[offset + 1] = UInt8((word >> 8) & 0xFF)
//            bytes[offset + 2] = UInt8((word >> 16) & 0xFF)
//            bytes[offset + 3] = UInt8((word >> 24) & 0xFF)
//            offset += 4
//        }
//        return bytes
//    }
}
