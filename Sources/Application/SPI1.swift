//
//  SPI1.swift
//  SAMD21E
//


//  SERCOM1 SPI for QT Py onboard NeoPixel (WS2812-over-SPI later; no DMA yet).
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
        case mhz3 = 3  //  24 MHz / 8   =  3 MHz
        case mhz1_5 = 7  //  24 MHz / 16  =  1.5 MHz
        case khz750 = 15  //  24 MHz / 32  =  750 kHz
        case khz375 = 31  //  24 MHz / 64  =  376 kHz   ← verified on LA (SPI0)
        case khz187 = 63  //  24 MHz / 128 =  187.5 kHz
    }
    
    static var mode: Mode = .mode0 {
        didSet { applyMode(mode) }
    }
    
    static var dataOrder: DataOrder = .mostSignificantBitFirst {
        didSet { applyDataOrder(dataOrder) }
    }
    
    static var clockRateSelect: ClockRateSelect = .khz375 {
        didSet { SERCOM1.SPI.baud = clockRateSelect.rawValue }
    }
    
    static var isReady: Bool { configureDone }
    
    private static var configureStep: Int = 0
    private static var configureDone: Bool = false
    
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
        case 4: ()
        case 5: GPIO.PA18.setDataDirection(.output)
            
            // SCK PA19 → SERCOM1 PAD3.
        case 6: GPIO.PA19.setPeripheralMux(.c)
        case 7: GPIO.PA19.setPeripheralMuxEnable(enabled: true)
        case 8: GPIO.PA19.setDataDirection(.output)
            
        case 9: spi1_enable_generic_clocks()
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
            configureDone = true
            return true
            
        default: ()
        }
        configureStep += 1
        return false
    }
    
    static func transmit(_ byte: UInt8) {
        var i: UInt32 = 0
        while i < 100_000 {
            if SERCOM1.SPI.intFlagDRE { break }
            i &+= 1
        }
        
        SERCOM1.SPI.data = UInt32(byte)
        
        var j: UInt32 = 0
        while j < 100_000 {
            if SERCOM1.SPI.intFlagTXC { break }
            j &+= 1
        }
        SERCOM1.SPI.intflagTXC = true
    }
    
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
