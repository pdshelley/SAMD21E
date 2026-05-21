//
//  SPI1.swift
//  SAMD21E
//


//  SERCOM1 SPI for QT Py onboard NeoPixel (WS2812-over-SPI from Application.swift).
//
//  PA18 — MOSI (SERCOM1 PAD2, mux C) → NeoPixel data
//  PA19 — SCK  (SERCOM1 PAD3, mux C); firmware only, not wired to the LED
//  PA15 — NeoPixel power (GPIO, active high)
//

enum SPI1 {

    enum Mode {
        /// CPOL=0, CPHA=0. Idle clock low; sample on leading (rising) edge.
        case mode0
        /// CPOL=0, CPHA=1. Idle clock low; sample on trailing (falling) edge.
        case mode1
        /// CPOL=1, CPHA=0. Idle clock high; sample on leading (falling) edge.
        case mode2
        /// CPOL=1, CPHA=1. Idle clock high; sample on trailing (rising) edge.
        case mode3
    }
    
    /// Bit ordering on the wire.
    enum DataOrder {
        case mostSignificantBitFirst
        case leastSignificantBitFirst
    }
    
    enum ClockRateSelect: UInt32 {
        case mhz12 = 0  //  24 MHz / 2   = 12 MHz
        case mhz6 = 1  //  24 MHz / 4   =  6 MHz
        case khz2400 = 9  //  48 MHz / 20  = 2.4 MHz (Adafruit NeoPixel SPI; GCLK0 after startup)
        case khz2180 = 10 //  48 MHz / 22  ≈ 2.18 MHz — default; try if colors bleed/yellow
        case khz2000 = 11 //  48 MHz / 24  = 2.0 MHz — slower still
        case mhz3 = 3  //  24 MHz / 8   =  3 MHz
        case mhz1_5 = 7  //  24 MHz / 16  =  1.5 MHz
        case khz750 = 15  //  24 MHz / 32  =  750 kHz
        case khz375 = 31  //  24 MHz / 64  =  376 kHz   ← verified on LA (SPI0)
        case khz187 = 63  //  24 MHz / 128 =  187.5 kHz
    }
    
    // No didSet — touching SERCOM1 here runs before configure() enables clocks (HardFault).
    static var mode: Mode = .mode0
    static var dataOrder: DataOrder = .mostSignificantBitFirst
    static var clockRateSelect: ClockRateSelect = .khz2400
    
    static var isReady: Bool { configureDone }
    
    private static var configureStep: Int = 0
    private static var configureDone: Bool = false
    private static var neoPixelDmaRunning: Bool = false
    private static let forceNeoPixelCpuBurst: Bool = false
    private static let neoPixelDmaChannel: UInt32 = 0
    private static let neoPixelDmaColorBytes: UInt32 = 9
    private static let neoPixelDmaLatchBytes: UInt32 = 90
    private static let neoPixelDmaFrameBytes: UInt32 = neoPixelDmaColorBytes + neoPixelDmaLatchBytes

    @_alignment(16)
    private struct RawDMACBuffer {
        var b00: UInt8 = 0; var b01: UInt8 = 0; var b02: UInt8 = 0; var b03: UInt8 = 0
        var b04: UInt8 = 0; var b05: UInt8 = 0; var b06: UInt8 = 0; var b07: UInt8 = 0
        var b08: UInt8 = 0; var b09: UInt8 = 0; var b10: UInt8 = 0; var b11: UInt8 = 0
        var b12: UInt8 = 0; var b13: UInt8 = 0; var b14: UInt8 = 0; var b15: UInt8 = 0
        var b16: UInt8 = 0; var b17: UInt8 = 0; var b18: UInt8 = 0; var b19: UInt8 = 0
        var b20: UInt8 = 0; var b21: UInt8 = 0; var b22: UInt8 = 0; var b23: UInt8 = 0
        var b24: UInt8 = 0; var b25: UInt8 = 0; var b26: UInt8 = 0; var b27: UInt8 = 0
        var b28: UInt8 = 0; var b29: UInt8 = 0; var b30: UInt8 = 0; var b31: UInt8 = 0
        var b32: UInt8 = 0; var b33: UInt8 = 0; var b34: UInt8 = 0; var b35: UInt8 = 0
        var b36: UInt8 = 0; var b37: UInt8 = 0; var b38: UInt8 = 0; var b39: UInt8 = 0
        var b40: UInt8 = 0; var b41: UInt8 = 0; var b42: UInt8 = 0; var b43: UInt8 = 0
        var b44: UInt8 = 0; var b45: UInt8 = 0; var b46: UInt8 = 0; var b47: UInt8 = 0
        var b48: UInt8 = 0; var b49: UInt8 = 0; var b50: UInt8 = 0; var b51: UInt8 = 0
        var b52: UInt8 = 0; var b53: UInt8 = 0; var b54: UInt8 = 0; var b55: UInt8 = 0
        var b56: UInt8 = 0; var b57: UInt8 = 0; var b58: UInt8 = 0; var b59: UInt8 = 0
        var b60: UInt8 = 0; var b61: UInt8 = 0; var b62: UInt8 = 0; var b63: UInt8 = 0
        var b64: UInt8 = 0; var b65: UInt8 = 0; var b66: UInt8 = 0; var b67: UInt8 = 0
        var b68: UInt8 = 0; var b69: UInt8 = 0; var b70: UInt8 = 0; var b71: UInt8 = 0
        var b72: UInt8 = 0; var b73: UInt8 = 0; var b74: UInt8 = 0; var b75: UInt8 = 0
        var b76: UInt8 = 0; var b77: UInt8 = 0; var b78: UInt8 = 0; var b79: UInt8 = 0
        var b80: UInt8 = 0; var b81: UInt8 = 0; var b82: UInt8 = 0; var b83: UInt8 = 0
        var b84: UInt8 = 0; var b85: UInt8 = 0; var b86: UInt8 = 0; var b87: UInt8 = 0
        var b88: UInt8 = 0; var b89: UInt8 = 0; var b90: UInt8 = 0; var b91: UInt8 = 0
        var b92: UInt8 = 0; var b93: UInt8 = 0; var b94: UInt8 = 0; var b95: UInt8 = 0
        var b96: UInt8 = 0; var b97: UInt8 = 0; var b98: UInt8 = 0
    }

    @_alignment(16)
    private struct RawDMACDescriptor {
        var btctrl: UInt32 = 0
        var srcaddr: UInt32 = 0
        var dstaddr: UInt32 = 0
        var descaddr: UInt32 = 0
    }

    private static var neoPixelDmaFrame = RawDMACBuffer()
    private static var neoPixelDmaDescriptor = RawDMACDescriptor()
    private static var neoPixelDmaWriteBack = RawDMACDescriptor()
    
    static func configure() -> Bool {
        if configureDone { return true }
        switch configureStep {
        case 0: PowerManager.portClockEnable = true
        case 1:
            GPIO.PA15.setDataDirection(.output)
            GPIO.PA15.setValue(.high)
            
        case 2: () // No MISO — NeoPixel is MOSI-only.
            
            // MOSI PA18 → SERCOM1 PAD2.
        case 3: GPIO.PA18.setPeripheralMux(.c)
            GPIO.PA18.setPeripheralMuxEnable(enabled: true)
            GPIO.PA18.setDataDirection(.output)
            
        case 4: ()
        case 5: () // GPIO.PA18.setDataDirection(.output)
            
            // SCK PA19 → SERCOM1 PAD3.
        case 6: GPIO.PA19.setPeripheralMux(.c)
        case 7: GPIO.PA19.setPeripheralMuxEnable(enabled: true)
        case 8: GPIO.PA19.setDataDirection(.output)
            
        case 9: enableSercom1GenericClocks()
        case 10:
            SERCOM1.SPI.enable = false
            _ = waitUntil({ !SERCOM1.SPI.syncbusyEnable })
        case 11:
            SERCOM1.SPI.softwareReset = true
            _ = waitUntil({
                !SERCOM1.SPI.syncbusySWRST && !SERCOM1.SPI.softwareReset
            })
        case 12: SERCOM1.SPI.operatingMode = .host
        case 13: SERCOM1.SPI.dataOutPinout = .mosi2_sck3
        case 14: SERCOM1.SPI.dataInPinout = .miso1
        case 15: SERCOM1.SPI.chsize = 0
        case 16:
            SERCOM1.SPI.rxen = false
            _ = waitUntil({ !SERCOM1.SPI.syncbusyCTRLB })
        case 17: SERCOM1.SPI.cpol = (mode == .mode2 || mode == .mode3)
        case 18: SERCOM1.SPI.cpha = (mode == .mode1 || mode == .mode3)
        case 19: SERCOM1.SPI.dord = (dataOrder == .leastSignificantBitFirst)
        case 20: SERCOM1.SPI.baud = clockRateSelect.rawValue
            
        case 21:
            SERCOM1.SPI.enable = true
            _ = waitUntil({ !SERCOM1.SPI.syncbusyEnable })
        case 22:
            var drained: UInt32 = 0
            while SERCOM1.SPI.intFlagRXC && drained < 8 {
                _ = SERCOM1.SPI.data
                drained &+= 1
            }
        case 23: SERCOM1.SPI.intflagTXC = true
        case 24:
            configureSercom1ForNeoPixel()
            neoPixelDmaRunning = forceNeoPixelCpuBurst ? false : neoPixelDmaBegin()
            configureDone = true
            return true
            
        default: ()
        }
        configureStep += 1
        return false
    }
    
    static func transmit(_ byte: UInt8) {
        transmitQueued(byte)
        transmitFlush()
    }
    
    /// Queue one byte; do not wait for end-of-frame (WS2812 needs back-to-back bytes).
    static func transmitQueued(_ byte: UInt8) {
        if !configureDone { return }
        _ = waitUntil({ SERCOM1.SPI.intFlagDRE })
        SERCOM1.SPI.data = UInt32(byte)
    }
    
    /// Wait until the last queued byte has fully shifted out.
    static func transmitFlush() {
        _ = waitUntil({ SERCOM1.SPI.intFlagTXC })
        SERCOM1.SPI.intflagTXC = true
    }

    private static func enableSercom1GenericClocks() {
        PowerManager.gclkClockEnable = true
        PowerManager.sercom1ClockEnable = true
        routeGenericClock(.sercom1Core)
        routeGenericClock(.sercomSlow)
    }

    private static func routeGenericClock(_ peripheral: GenericClockController.PeripheralClockID) {
        _volatileRegisterWriteUInt16(
            GCLK_BASE + 0x02,
            UInt16(
                (UInt32(1) << 14) |
                ((GenericClockController.Generator.generator0.rawValue & 0x0F) << 8) |
                (peripheral.rawValue & 0x3F)
            )
        )
        _ = waitUntil({ !GenericClockController.synchronizationBusy })
    }

    private static func configureSercom1ForNeoPixel() {
        PowerManager.sercom1ClockEnable = true

        SERCOM1.SPI.enable = false
        _ = waitUntil({ !SERCOM1.SPI.syncbusyEnable })

        SERCOM1.SPI.softwareReset = true
        _ = waitUntil({
            !SERCOM1.SPI.syncbusySWRST && !SERCOM1.SPI.softwareReset
        })

        SERCOM1.SPI.controlA =
            (UInt32(1) << 16) |  // DOPO: MOSI PAD2, SCK PAD3.
            (UInt32(1) << 20) |  // DIPO: unused MISO PAD1.
            (UInt32(3) << 2)     // MODE: SPI master.
        SERCOM1.SPI.ctrlb = 0
        _ = waitUntil({ !SERCOM1.SPI.syncbusyCTRLB })
        SERCOM1.SPI.baud = ClockRateSelect.khz2400.rawValue

        SERCOM1.SPI.enable = true
        _ = waitUntil({ !SERCOM1.SPI.syncbusyEnable })

        var drained: UInt32 = 0
        while SERCOM1.SPI.intFlagRXC && drained < 8 {
            _ = SERCOM1.SPI.data
            drained &+= 1
        }
        SERCOM1.SPI.intflagTXC = true
    }

    private static func address<T>(of value: inout T) -> UInt32 {
        withUnsafeMutablePointer(to: &value) { pointer in
            UInt32(truncatingIfNeeded: UInt(bitPattern: pointer))
        }
    }

    private static func writeRegisterUInt8(_ address: UInt, _ value: UInt8) {
        UnsafeMutablePointer<UInt8>(bitPattern: address)!.pointee = value
    }

    private static func neoPixelExpandByteToFrame(_ value: UInt8, _ b0: inout UInt8, _ b1: inout UInt8, _ b2: inout UInt8) {
        var acc: UInt32 = 0
        var bits = value
        for _ in 0..<8 {
            let one = (bits & 0x80) != 0
            acc = (acc << 3) | (one ? 0b110 : 0b100)
            bits &<<= 1
        }
        b0 = UInt8((acc >> 16) & 0xFF)
        b1 = UInt8((acc >> 8) & 0xFF)
        b2 = UInt8(acc & 0xFF)
    }

    private static func neoPixelBuildDMAFrame(red: UInt8, green: UInt8, blue: UInt8) {
        neoPixelExpandByteToFrame(green, &neoPixelDmaFrame.b00, &neoPixelDmaFrame.b01, &neoPixelDmaFrame.b02)
        neoPixelExpandByteToFrame(red,   &neoPixelDmaFrame.b03, &neoPixelDmaFrame.b04, &neoPixelDmaFrame.b05)
        neoPixelExpandByteToFrame(blue,  &neoPixelDmaFrame.b06, &neoPixelDmaFrame.b07, &neoPixelDmaFrame.b08)
    }

    private static func neoPixelDmaBegin() -> Bool {
        if neoPixelDmaRunning { return true }
        // Diagnostic: send one frame via CPU burst so we know NeoPixel works,
        // then let DMAC take over. If LED stays this color, DMAC never started.
        neoPixelBuildFrame(red: 0, green: 50, blue: 0)
        neoPixelBurstTransmit()
        neoPixelBuildDMAFrame(red: 0, green: 0, blue: 0)
        if !neoPixelConfigureDMALoop() { return false }
        neoPixelDmaRunning = true
        return true
    }

    private static func neoPixelConfigureDMALoop() -> Bool {
        PowerManager.dmacAHBClockEnable = true
        PowerManager.dmacClockEnable = true

        _volatileRegisterWriteUInt16(DMAC_BASE + 0x00, 0)
        _volatileRegisterWriteUInt16(DMAC_BASE + 0x00, 1)
        if !waitUntil({ (_volatileRegisterReadUInt32(DMAC_BASE) & 1) == 0 }) { return false }

        let descriptorAddress = address(of: &neoPixelDmaDescriptor)
        let writeBackAddress = address(of: &neoPixelDmaWriteBack)
        let sourceAddress = address(of: &neoPixelDmaFrame)
        let destinationAddress = UInt32(truncatingIfNeeded: SERCOM1_BASE + 0x28)

        neoPixelDmaWriteBack = RawDMACDescriptor()
        neoPixelDmaDescriptor = RawDMACDescriptor()

        withUnsafeMutablePointer(to: &neoPixelDmaDescriptor) { ptr in
            let d = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt32.self)
            d[0] = UInt32(1) | (UInt32(1) << 10) | (UInt32(99) << 16)
            d[1] = sourceAddress
            d[2] = destinationAddress
            d[3] = descriptorAddress
        }

        _volatileRegisterWriteUInt32(DMAC_BASE + 0x34, descriptorAddress)
        _volatileRegisterWriteUInt32(DMAC_BASE + 0x38, writeBackAddress)
        _volatileRegisterWriteUInt16(DMAC_BASE + 0x00, UInt16((UInt32(1) << 1) | (UInt32(0x0F) << 8)))

        writeRegisterUInt8(DMAC_BASE + 0x3F, UInt8(neoPixelDmaChannel & 0x0F))
        _volatileRegisterWriteUInt32(
            DMAC_BASE + 0x44,
            0 | (UInt32(4) << 8) | (UInt32(2) << 22)
        )
        writeRegisterUInt8(DMAC_BASE + 0x40, 0x02)
        _volatileRegisterWriteUInt32(DMAC_BASE + 0x10, UInt32(1) << neoPixelDmaChannel)
        return true
    }

    private static func neoPixelDmaSetPixel(red: UInt8, green: UInt8, blue: UInt8) {
        if !neoPixelDmaRunning { return }
        neoPixelBuildDMAFrame(red: red, green: green, blue: blue)
    }
    
    private static let neoPixelLatchBytes: UInt32 = 32
    private static let neoPixelFrameBytes: UInt32 = 41  // 9 color + 32 latch (neoTx00…neoTx40)
    
    // Pre-built frame (build phase may take time; burst transmit is gapless on DRE).
    private static var neoTx00: UInt8 = 0
    private static var neoTx01: UInt8 = 0
    private static var neoTx02: UInt8 = 0
    private static var neoTx03: UInt8 = 0
    private static var neoTx04: UInt8 = 0
    private static var neoTx05: UInt8 = 0
    private static var neoTx06: UInt8 = 0
    private static var neoTx07: UInt8 = 0
    private static var neoTx08: UInt8 = 0
    private static var neoTx09: UInt8 = 0
    private static var neoTx10: UInt8 = 0
    private static var neoTx11: UInt8 = 0
    private static var neoTx12: UInt8 = 0
    private static var neoTx13: UInt8 = 0
    private static var neoTx14: UInt8 = 0
    private static var neoTx15: UInt8 = 0
    private static var neoTx16: UInt8 = 0
    private static var neoTx17: UInt8 = 0
    private static var neoTx18: UInt8 = 0
    private static var neoTx19: UInt8 = 0
    private static var neoTx20: UInt8 = 0
    private static var neoTx21: UInt8 = 0
    private static var neoTx22: UInt8 = 0
    private static var neoTx23: UInt8 = 0
    private static var neoTx24: UInt8 = 0
    private static var neoTx25: UInt8 = 0
    private static var neoTx26: UInt8 = 0
    private static var neoTx27: UInt8 = 0
    private static var neoTx28: UInt8 = 0
    private static var neoTx29: UInt8 = 0
    private static var neoTx30: UInt8 = 0
    private static var neoTx31: UInt8 = 0
    private static var neoTx32: UInt8 = 0
    private static var neoTx33: UInt8 = 0
    private static var neoTx34: UInt8 = 0
    private static var neoTx35: UInt8 = 0
    private static var neoTx36: UInt8 = 0
    private static var neoTx37: UInt8 = 0
    private static var neoTx38: UInt8 = 0
    private static var neoTx39: UInt8 = 0
    private static var neoTx40: UInt8 = 0
    
    private static func neoTxWrite(_ index: UInt32, _ value: UInt8) {
        switch index {
        case 0: neoTx00 = value
        case 1: neoTx01 = value
        case 2: neoTx02 = value
        case 3: neoTx03 = value
        case 4: neoTx04 = value
        case 5: neoTx05 = value
        case 6: neoTx06 = value
        case 7: neoTx07 = value
        case 8: neoTx08 = value
        case 9: neoTx09 = value
        case 10: neoTx10 = value
        case 11: neoTx11 = value
        case 12: neoTx12 = value
        case 13: neoTx13 = value
        case 14: neoTx14 = value
        case 15: neoTx15 = value
        case 16: neoTx16 = value
        case 17: neoTx17 = value
        case 18: neoTx18 = value
        case 19: neoTx19 = value
        case 20: neoTx20 = value
        case 21: neoTx21 = value
        case 22: neoTx22 = value
        case 23: neoTx23 = value
        case 24: neoTx24 = value
        case 25: neoTx25 = value
        case 26: neoTx26 = value
        case 27: neoTx27 = value
        case 28: neoTx28 = value
        case 29: neoTx29 = value
        case 30: neoTx30 = value
        case 31: neoTx31 = value
        case 32: neoTx32 = value
        case 33: neoTx33 = value
        case 34: neoTx34 = value
        case 35: neoTx35 = value
        case 36: neoTx36 = value
        case 37: neoTx37 = value
        case 38: neoTx38 = value
        case 39: neoTx39 = value
        case 40: neoTx40 = value
        default: break
        }
    }
    
    private static func neoTxRead(_ index: UInt32) -> UInt8 {
        switch index {
        case 0: return neoTx00
        case 1: return neoTx01
        case 2: return neoTx02
        case 3: return neoTx03
        case 4: return neoTx04
        case 5: return neoTx05
        case 6: return neoTx06
        case 7: return neoTx07
        case 8: return neoTx08
        case 9: return neoTx09
        case 10: return neoTx10
        case 11: return neoTx11
        case 12: return neoTx12
        case 13: return neoTx13
        case 14: return neoTx14
        case 15: return neoTx15
        case 16: return neoTx16
        case 17: return neoTx17
        case 18: return neoTx18
        case 19: return neoTx19
        case 20: return neoTx20
        case 21: return neoTx21
        case 22: return neoTx22
        case 23: return neoTx23
        case 24: return neoTx24
        case 25: return neoTx25
        case 26: return neoTx26
        case 27: return neoTx27
        case 28: return neoTx28
        case 29: return neoTx29
        case 30: return neoTx30
        case 31: return neoTx31
        case 32: return neoTx32
        case 33: return neoTx33
        case 34: return neoTx34
        case 35: return neoTx35
        case 36: return neoTx36
        case 37: return neoTx37
        case 38: return neoTx38
        case 39: return neoTx39
        case 40: return neoTx40
        default: return 0
        }
    }
    
    private static func neoPixelExpandIntoBuffer(_ value: UInt8, at index: UInt32) -> UInt32 {
        var acc: UInt32 = 0
        var bits = value
        for _ in 0..<8 {
            let one = (bits & 0x80) != 0
            acc = (acc << 3) | (one ? 0b110 : 0b100)
            bits &<<= 1
        }
        neoTxWrite(index, UInt8((acc >> 16) & 0xFF))
        neoTxWrite(index &+ 1, UInt8((acc >> 8) & 0xFF))
        neoTxWrite(index &+ 2, UInt8(acc & 0xFF))
        return index &+ 3
    }
    
    private static func neoPixelBuildFrame(red: UInt8, green: UInt8, blue: UInt8) {
        var n: UInt32 = 0
        // WS2812 wire order is GRB (not RGB).
        n = neoPixelExpandIntoBuffer(green, at: n)
        n = neoPixelExpandIntoBuffer(red, at: n)
        n = neoPixelExpandIntoBuffer(blue, at: n)
        var z: UInt32 = 0
        while z < neoPixelLatchBytes {
            neoTxWrite(n, 0)
            n &+= 1
            z &+= 1
        }
    }
    
    /// Shift out `neoTx` back-to-back: poll DRE only (no waitUntil / no TXC between bytes).
    private static func neoPixelBurstTransmit() {
        var i: UInt32 = 0
        while i < neoPixelFrameBytes {
            while !SERCOM1.SPI.intFlagDRE { }
            SERCOM1.SPI.data = UInt32(neoTxRead(i))
            i &+= 1
        }
        while !SERCOM1.SPI.intFlagTXC { }
        SERCOM1.SPI.intflagTXC = true
    }
    
    /// One WS2812 pixel (GRB on the wire).
    /// DMA path (default): update looping buffer only; SPI+DMAC never stop (Adafruit ZeroDMA style).
    /// Fallback: CPU DRE burst if DMA setup failed.
    static func transmitNeoPixel(red: UInt8, green: UInt8, blue: UInt8) {
        if !configureDone { return }
        if neoPixelDmaRunning {
            neoPixelDmaSetPixel(red: red, green: green, blue: blue)
            return
        }
        neoPixelBuildFrame(red: red, green: green, blue: blue)
        neoPixelBurstTransmit()
    }
    
    /// Looping DMAC to SERCOM1 fixes MOSI idle-high between frames (90 latch bytes in DMA buffer).
    /// Tune `clockRateSelect` only for CPU burst fallback: .khz2180, .khz2000, .khz2400.
    
    private static func applyMode(_ mode: Mode) {
        switch mode {
        case .mode0:
            SERCOM1.SPI.cpol = false
            SERCOM1.SPI.cpha = false
        case .mode1:
            SERCOM1.SPI.cpol = false
            SERCOM1.SPI.cpha = true
        case .mode2:
            SERCOM1.SPI.cpol = true
            SERCOM1.SPI.cpha = false
        case .mode3:
            SERCOM1.SPI.cpol = true
            SERCOM1.SPI.cpha = true
        }
    }
    
    private static func applyDataOrder(_ order: DataOrder) {
        SERCOM1.SPI.dord = (order == .leastSignificantBitFirst)
    }
    
    private static func waitUntil(
        _ condition: () -> Bool,
        maxIterations: UInt32 = 200_000
    ) -> Bool {
        var i: UInt32 = 0
        while i < maxIterations {
            if condition() { return true }
            i &+= 1
        }
        return false
    }
}
