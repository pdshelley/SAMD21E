////
////  UserRowWriter.swift
////  SAMD21E
////
//
//enum UserRowWriteError {
//    case invalidLength
//    case controllerTimeout
//    case programmingError
//    case lockError
//    case nvmError
//}
//
//struct UserRowWriter {
//    @inline(__always)
//    private static func storeWord(address: UInt32, value: UInt32) {
//        UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!.pointee = value
//    }
//
//    private static func waitForReady(maxPolls: Int = 1_000_000) -> Bool {
//        var polls = 0
//        while !NonvolatileMemoryController.isReady {
//            polls += 1
//            if polls >= maxPolls { return false }
//        }
//        return true
//    }
//
//    private static func clearErrors() {
//        NonvolatileMemoryController.hasError = true
//        NonvolatileMemoryController.nvmError = true
//        NonvolatileMemoryController.lockError = true
//        NonvolatileMemoryController.programmingError = true
//    }
//
//    private static func currentError() -> UserRowWriteError? {
//        if NonvolatileMemoryController.programmingError { return .programmingError }
//        if NonvolatileMemoryController.lockError { return .lockError }
//        if NonvolatileMemoryController.nvmError || NonvolatileMemoryController.hasError { return .nvmError }
//        return nil
//    }
//
//    static func writeBytes(_ bytes: [UInt8]) -> UserRowWriteError? {
//        guard bytes.count == UserRowReader.byteCount else { return .invalidLength }
//        guard waitForReady() else { return .controllerTimeout }
//
//        clearErrors()
//
//        let oldManualWrite = NonvolatileMemoryController.manualWrite
//        NonvolatileMemoryController.manualWrite = true
//        defer { NonvolatileMemoryController.manualWrite = oldManualWrite }
//
//        let targetAddress = UserRowReader.baseAddress >> 1
//
//        NonvolatileMemoryController.targetAddress = targetAddress
//        NonvolatileMemoryController.executeCommand(.eraseAuxiliaryRow)
//        guard waitForReady() else { return .controllerTimeout }
//        if let error = currentError() { return error }
//
//        NonvolatileMemoryController.targetAddress = targetAddress
//        NonvolatileMemoryController.executeCommand(.clearPageBuffer)
//        guard waitForReady() else { return .controllerTimeout }
//        if let error = currentError() { return error }
//
//        var offset = 0
//        while offset < UserRowReader.byteCount {
//            let word =
//                UInt32(bytes[offset + 0])
//                | (UInt32(bytes[offset + 1]) << 8)
//                | (UInt32(bytes[offset + 2]) << 16)
//                | (UInt32(bytes[offset + 3]) << 24)
//            storeWord(address: UserRowReader.baseAddress + UInt32(offset), value: word)
//            offset += 4
//        }
//
//        NonvolatileMemoryController.targetAddress = targetAddress
//        NonvolatileMemoryController.executeCommand(.writeAuxiliaryPage)
//        guard waitForReady() else { return .controllerTimeout }
//        return currentError()
//    }
//}
