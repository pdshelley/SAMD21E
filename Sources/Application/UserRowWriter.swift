//
//  UserRowWriter.swift
//  SAMD21E
//

struct UserRowWriter {
    static let baseAddress: UInt = 0x0080_4000
    static let byteCount: Int = 64
    private static let readyPollLimit: UInt32 = 1_000_000

    static func writeMACAddress(
        _ b0: UInt8,
        _ b1: UInt8,
        _ b2: UInt8,
        _ b3: UInt8,
        _ b4: UInt8,
        _ b5: UInt8
    ) -> Bool {
        var bytes = readBytes()
        bytes[0] = b0
        bytes[1] = b1
        bytes[2] = b2
        bytes[3] = b3
        bytes[4] = b4
        bytes[5] = b5
        return write(bytes)
    }

    private static func write(_ bytes: [UInt8]) -> Bool {
        if bytes.count != byteCount { return false }

        let previousManualWrite = NonvolatileMemoryController.manualWrite
        NonvolatileMemoryController.manualWrite = true
        defer { NonvolatileMemoryController.manualWrite = previousManualWrite }

        if !waitUntilReady() { return false }
        clearErrors()

        NonvolatileMemoryController.targetAddress = UInt32(baseAddress >> 1)
        NonvolatileMemoryController.executeCommand(.eraseAuxiliaryRow)
        if !waitUntilReady() { return false }
        if NonvolatileMemoryController.nvmError { return false }

        NonvolatileMemoryController.executeCommand(.clearPageBuffer)
        if !waitUntilReady() { return false }
        if NonvolatileMemoryController.nvmError { return false }

        var offset = 0
        while offset < byteCount {
            let halfWord = packHalfWord(bytes, offset: offset)
            _volatileRegisterWriteUInt16(baseAddress + UInt(offset), halfWord)
            offset += 2
        }

        NonvolatileMemoryController.targetAddress = UInt32(baseAddress >> 1)
        NonvolatileMemoryController.executeCommand(.writeAuxiliaryPage)
        if !waitUntilReady() { return false }
        if NonvolatileMemoryController.nvmError { return false }

        let written = readBytes()
        return written[0] == bytes[0]
            && written[1] == bytes[1]
            && written[2] == bytes[2]
            && written[3] == bytes[3]
            && written[4] == bytes[4]
            && written[5] == bytes[5]
    }

    private static func readBytes() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        var offset = 0
        while offset < byteCount {
            let word = _volatileRegisterReadUInt32(baseAddress + UInt(offset))
            bytes[offset + 0] = UInt8((word >> 0) & 0xFF)
            bytes[offset + 1] = UInt8((word >> 8) & 0xFF)
            bytes[offset + 2] = UInt8((word >> 16) & 0xFF)
            bytes[offset + 3] = UInt8((word >> 24) & 0xFF)
            offset += 4
        }
        return bytes
    }

    @inline(__always)
    private static func packHalfWord(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset + 0]) << 0
        | UInt16(bytes[offset + 1]) << 8
    }

    @inline(__always)
    private static func waitUntilReady() -> Bool {
        var polls: UInt32 = 0
        while !NonvolatileMemoryController.isReady {
            polls &+= 1
            if polls >= readyPollLimit { return false }
        }
        return true
    }

    @inline(__always)
    private static func clearErrors() {
        if NonvolatileMemoryController.hasError {
            NonvolatileMemoryController.hasError = true
        }
        if NonvolatileMemoryController.nvmError {
            NonvolatileMemoryController.nvmError = true
        }
    }
}

