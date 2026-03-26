//===----------------------------------------------------------------------===//
//
// This source file is part of the Embedded Swift QT Py SAMD21 Example
//
// Copyright (c) 2026 Paul Shelley.
// Licensed under MIT
//
//===----------------------------------------------------------------------===//

//import SAMD21E  // To keep code contained and clean.
//import Support  // Needed for the busyWait()
//
//@main
//struct Application {
//    static func main() {
//        // Set PA02 (A0) to Output
//        let PORT_BASE: UInt32 = 0x41004400
//        let DIRSET = PORT_BASE + 0x08
//        let OUTSET = PORT_BASE + 0x18
//        let OUTCLR = PORT_BASE + 0x14
//        let PINCFG2 = PORT_BASE + 0x44 + 2  // pincfg[2]
//
//        // PA02 = output + GPIO mode
//        volatile_store_uint32_t(UnsafeMutablePointer(bitPattern: UInt(DIRSET))!, 1 << 2)
//        volatile_store_uint8_t(UnsafeMutablePointer(bitPattern: UInt(PINCFG2))!, 0)  // pmuxen = 0
//
//        while true {
//            // Set PA02 to High
//            volatile_store_uint32_t(UnsafeMutablePointer(bitPattern: UInt(OUTSET))!, 1 << 2)
//
//            busyWait(250_000)
//
//            // Set PA02 to Low
//            volatile_store_uint32_t(UnsafeMutablePointer(bitPattern: UInt(OUTCLR))!, 1 << 2)
//
//            busyWait(250_000)
//        }
//    }
//}


@main
struct Application {
    // Enable DFLL48M as main clock source (48 MHz internal)
    let SYSCTRL_BASE: UInt32 = 0x40000800
    let OSC8M = SYSCTRL_BASE + 0x20  // rough offset - check datasheet for exact
    // ... full DFLL enable sequence is ~20-30 lines. See bare-metal examples below.

    let GCLK_BASE: UInt32 = 0x40000C00
    // Enable clock for PORT, etc.
    static func main() {
        while true {
            // do nothing - just spin
        }
    }
}
