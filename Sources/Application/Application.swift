//
//  Application.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

// Blink PA02 at 1-second intervals using direct memory-mapped I/O.
//
// PORT Group A base address: 0x41004400  (SAMD21 datasheet §23.8)
//   DIRSET  +0x08  write 1 to make the corresponding pin an output
//   OUTCLR  +0x14  write 1 to drive the corresponding pin low
//   OUTSET  +0x18  write 1 to drive the corresponding pin high
//
// PA02 is bit 2, so the mask is (1 << 2) = 0x00000004.

func appInit() {
    UnsafeMutablePointer<UInt32>(bitPattern: 0x41004408 as UInt)!.pointee = 1 << 2  // DIRSET: PA02 output
    UnsafeMutablePointer<UInt32>(bitPattern: 0x41004414 as UInt)!.pointee = 1 << 2  // OUTCLR: start low
}

func appMain() {
    UnsafeMutablePointer<UInt32>(bitPattern: 0x41004418 as UInt)!.pointee = 1 << 2  // OUTSET: PA02 high
    delay(1000)
    UnsafeMutablePointer<UInt32>(bitPattern: 0x41004414 as UInt)!.pointee = 1 << 2  // OUTCLR: PA02 low
    delay(1000)
}
