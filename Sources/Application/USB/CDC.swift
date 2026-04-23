//
//  CDC.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/20/26.
//

/// USB CDC (TinyUSB). Call `initialize()` once, `task()` every loop.
enum CDC {

    static func initialize() {
        cdc_init()
    }

    static func task() {
        cdc_task()
    }

    static var isConnected: Bool {
        cdc_is_connected()
    }

    private static var writeAvailable: UInt32 {
        cdc_write_available()
    }

    private static func flush() {
        cdc_flush()
    }

    static func print(_ string: StaticString) {
        cdc_write(string.utf8Start, UInt32(string.utf8CodeUnitCount))
        flush()
    }

    static func print(_ value: UInt8) {
        let ascii = value.asciiDigits()
        if ascii.count >= 1 { _ = cdc_write_byte(ascii.digits.0) }
        if ascii.count >= 2 { _ = cdc_write_byte(ascii.digits.1) }
        if ascii.count >= 3 { _ = cdc_write_byte(ascii.digits.2) }
        flush()
    }

    static func print(_ value: UInt16) {
        let ascii = value.asciiDigits()
        if ascii.count >= 1 { _ = cdc_write_byte(ascii.digits.0) }
        if ascii.count >= 2 { _ = cdc_write_byte(ascii.digits.1) }
        if ascii.count >= 3 { _ = cdc_write_byte(ascii.digits.2) }
        if ascii.count >= 4 { _ = cdc_write_byte(ascii.digits.3) }
        if ascii.count >= 5 { _ = cdc_write_byte(ascii.digits.4) }
        flush()
    }

    static func print(_ value: UInt32) {
        let ascii = value.asciiDigits()
        if ascii.count >= 1 { _ = cdc_write_byte(ascii.digits.0) }
        if ascii.count >= 2 { _ = cdc_write_byte(ascii.digits.1) }
        if ascii.count >= 3 { _ = cdc_write_byte(ascii.digits.2) }
        if ascii.count >= 4 { _ = cdc_write_byte(ascii.digits.3) }
        if ascii.count >= 5 { _ = cdc_write_byte(ascii.digits.4) }
        if ascii.count >= 6 { _ = cdc_write_byte(ascii.digits.5) }
        if ascii.count >= 7 { _ = cdc_write_byte(ascii.digits.6) }
        if ascii.count >= 8 { _ = cdc_write_byte(ascii.digits.7) }
        if ascii.count >= 9 { _ = cdc_write_byte(ascii.digits.8) }
        if ascii.count >= 10 { _ = cdc_write_byte(ascii.digits.9) }
        flush()
    }
}

extension UInt8 {
    @inline(__always)
    func asciiDigits() -> (digits: (UInt8, UInt8, UInt8), count: Int) {
        if self >= 100 {
            return (digits: (self / 100 + 48, (self / 10) % 10 + 48, self % 10 + 48), count: 3)
        }
        if self >= 10 {
            return (digits: (self / 10 + 48, self % 10 + 48, 0), count: 2)
        }
        return (digits: (self + 48, 0, 0), count: 1)
    }
}

extension UInt16 {
    @inline(__always)
    func asciiDigits() -> (digits: (UInt8, UInt8, UInt8, UInt8, UInt8), count: Int) {
        var v = UInt32(self)
        if v == 0 {
            return (digits: (48, 0, 0, 0, 0), count: 1)
        }
        var rev: (UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0)
        var k = 0
        while v > 0 {
            let d = UInt8(v % 10) + 48
            switch k {
            case 0: rev.0 = d
            case 1: rev.1 = d
            case 2: rev.2 = d
            case 3: rev.3 = d
            default: rev.4 = d
            }
            k += 1
            v /= 10
        }
        var buffer: (UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0)
        var i = 0
        while i < k {
            let from = k - 1 - i
            let ch: UInt8
            switch from {
            case 0: ch = rev.0
            case 1: ch = rev.1
            case 2: ch = rev.2
            case 3: ch = rev.3
            default: ch = rev.4
            }
            switch i {
            case 0: buffer.0 = ch
            case 1: buffer.1 = ch
            case 2: buffer.2 = ch
            case 3: buffer.3 = ch
            default: buffer.4 = ch
            }
            i += 1
        }
        return (digits: buffer, count: k)
    }
}

extension UInt32 {
    @inline(__always)
    func asciiDigits() -> (
        digits: (
            UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8
        ),
        count: Int
    ) {
        var v = self
        if v == 0 {
            return (digits: (48, 0, 0, 0, 0, 0, 0, 0, 0, 0), count: 1)
        }
        var rev: (
            UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var k = 0
        while v > 0 {
            let d = UInt8(v % 10) + 48
            switch k {
            case 0: rev.0 = d
            case 1: rev.1 = d
            case 2: rev.2 = d
            case 3: rev.3 = d
            case 4: rev.4 = d
            case 5: rev.5 = d
            case 6: rev.6 = d
            case 7: rev.7 = d
            case 8: rev.8 = d
            default: rev.9 = d
            }
            k += 1
            v /= 10
        }
        var buffer: (
            UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var i = 0
        while i < k {
            let from = k - 1 - i
            let ch: UInt8
            switch from {
            case 0: ch = rev.0
            case 1: ch = rev.1
            case 2: ch = rev.2
            case 3: ch = rev.3
            case 4: ch = rev.4
            case 5: ch = rev.5
            case 6: ch = rev.6
            case 7: ch = rev.7
            case 8: ch = rev.8
            default: ch = rev.9
            }
            switch i {
            case 0: buffer.0 = ch
            case 1: buffer.1 = ch
            case 2: buffer.2 = ch
            case 3: buffer.3 = ch
            case 4: buffer.4 = ch
            case 5: buffer.5 = ch
            case 6: buffer.6 = ch
            case 7: buffer.7 = ch
            case 8: buffer.8 = ch
            default: buffer.9 = ch
            }
            i += 1
        }
        return (digits: buffer, count: k)
    }
}
