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
