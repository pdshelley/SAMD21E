//
//  CDC.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/20/26.
//


/// USB CDC ACM interface backed by TinyUSB.
///
/// Typical usage:
///
///     func appInit() {
///         CDC.initialize()
///     }
///     func appMain() {
///         CDC.task()           // drives the USB stack — call every loop
///         CDC.print("tick\n")
///     }
///
/// All write APIs queue bytes into TinyUSB's TX FIFO. Data is sent to the host
/// on the next USB full-speed frame (every 1 ms) or when `flush()` is called.
enum CDC {

    /// Enable the USB peripheral clock and start TinyUSB. Call once from appInit().
    static func initialize() {
        cdc_init()
    }

    /// Drive the TinyUSB device stack. Must be called on every main-loop iteration.
    static func task() {
        cdc_task()
    }

    /// True when a host terminal has the CDC port open.
    static var isConnected: Bool {
        cdc_is_connected()
    }

    /// Write a compile-time string literal. Zero-copy — the literal lives in flash.
    @discardableResult
    static func write(_ string: StaticString) -> UInt32 {
        cdc_write(string.utf8Start, UInt32(string.utf8CodeUnitCount))
    }

    /// Write a single byte into the TX FIFO.
    @discardableResult
    static func write(_ byte: UInt8) -> UInt32 {
        withUnsafePointer(to: byte) { cdc_write($0, 1) }
    }

    /// Flush the TX FIFO, pushing any buffered bytes to the host immediately.
    static func flush() {
        cdc_flush()
    }

    /// Write a static string and flush. Convenient for one-shot debug lines.
    static func print(_ string: StaticString) {
        cdc_write(string.utf8Start, UInt32(string.utf8CodeUnitCount))
        cdc_flush()
    }
}
