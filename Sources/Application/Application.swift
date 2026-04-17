// Blink PA02 at 1-second intervals using direct memory-mapped I/O.
//
// PORT Group A base address: 0x41004400  (SAMD21 datasheet §23.8)
//   DIRSET  +0x08  write 1 to make the corresponding pin an output
//   OUTCLR  +0x14  write 1 to drive the corresponding pin low
//   OUTSET  +0x18  write 1 to drive the corresponding pin high
//
// PA02 is bit 2, so the mask is (1 << 2) = 0x00000004.

private let portaDirset = UnsafeMutablePointer<UInt32>(bitPattern: 0x41004408)!
private let portaOutclr = UnsafeMutablePointer<UInt32>(bitPattern: 0x41004414)!
private let portaOutset = UnsafeMutablePointer<UInt32>(bitPattern: 0x41004418)!

private let pa02: UInt32 = 1 << 2

@_cdecl("app_init")
func appInit() {
    portaDirset.pointee = pa02
    portaOutclr.pointee = pa02
}

@_cdecl("app_main")
func appMain() {
    portaOutset.pointee = pa02
    delay(1000)
    portaOutclr.pointee = pa02
    delay(1000)
}
