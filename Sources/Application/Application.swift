//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2026 Paul Shelley.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

@main
struct Application {
  static func main() {
    // Enable clock for PORT
    apbcmask.pointee |= 1 << 2

    // Set PA02 as output
    dirsetA.pointee = 1 << 2

    while true {
      outSetA.pointee = 1 << 2  // High
      delay(milliseconds: 500)
      outClrA.pointee = 1 << 2  // Low
      delay(milliseconds: 500)
    }
  }

  static func delay(milliseconds: Int) {
    // Busy wait (approximate for 48MHz clock; adjust loop count if timing is off)
    for _ in 0..<(milliseconds * 6000) {}
  }
}

// MMIO pointers
let apbcmask = UnsafeMutablePointer<UInt32>(bitPattern: 0x40000420)!
let dirsetA = UnsafeMutablePointer<UInt32>(bitPattern: 0x41004408)!
let outSetA = UnsafeMutablePointer<UInt32>(bitPattern: 0x41004418)!
let outClrA = UnsafeMutablePointer<UInt32>(bitPattern: 0x41004414)!
