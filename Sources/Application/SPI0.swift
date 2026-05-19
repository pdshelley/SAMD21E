//
//  SPI0.swift
//  SAMD21E
//


enum SPI0 {
    
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
        case khz375 = 31  //  24 MHz / 64  =  376 kHz   ← verified on LA
        case khz187 = 63  //  24 MHz / 128 =  187.5 kHz
    }
    
    static var mode: Mode = .mode0 {
        didSet { applyMode(mode) }
    }
    
    static var dataOrder: DataOrder = .mostSignificantBitFirst {
        didSet { applyDataOrder(dataOrder) }
    }
    
    static var clockRateSelect: ClockRateSelect = .khz375 {
        didSet { SERCOM0.SPI.baud = clockRateSelect.rawValue }
    }
    
    static var isReady: Bool { configureDone }
    
    private static var configureStep: Int = 0
    private static var configureDone: Bool = false
    
    
    private static func pulsePA02Configure2Marker(idleLevel: DigitalValue) {
        if idleLevel == .high {
            GPIO.PA02.setValue(.low)
            delay_busy_microseconds(10)
            GPIO.PA02.setValue(.high)
        } else {
            GPIO.PA02.setValue(.high)
            delay_busy_microseconds(10)
            GPIO.PA02.setValue(.low)
        }
    }
    
    static func configure() -> Bool {
        if configureDone { return true }
        switch configureStep {
        case 0: PowerManager.portClockEnable = true
        case 1: GPIO.PA04.setDataDirection(.output)
            GPIO.PA04.setValue(.high)
            
            // MISO / MOSI / SCK muxing (AN2465 5.1.6)
            GPIO.PA09.setPeripheralMux(.c)
            GPIO.PA09.setPeripheralMuxEnable(enabled: true)
            GPIO.PA09.setInputEnable(enabled: true)
            
            GPIO.PA09.setDataDirection(.input)
            
            
        case 2: () // GPIO.PA09.setDataDirection(.input)
            
            // MOSI PA10 → SERCOM0 PAD2.
        case 3: GPIO.PA10.setPeripheralMux(.c) // GPIO.PORTA.setPeripheralMux(pin: 10, function: sercomFunctionC)
            GPIO.PA10.setPeripheralMuxEnable(enabled: true)
        case 4: ()
        case 5: GPIO.PA10.setDataDirection(.output)
            
            // SCK PA11 → SERCOM0 PAD3.
        case 6: GPIO.PA11.setPeripheralMux(.c) // GPIO.PORTA.setPeripheralMux(pin: 11, function: sercomFunctionC)
        case 7: GPIO.PA11.setPeripheralMuxEnable(enabled: true)
        case 8: GPIO.PA11.setDataDirection(.output)
            
        case 9: spi0_enable_generic_clocks()  // TODO: Remove the dependency on C.
        case 10:
            SERCOM0.SPI.enable = false
            _ = waitUntil({ !SERCOM0.SPI.syncbusyEnable })
        case 11:
            SERCOM0.SPI.softwareReset = true
            _ = waitUntil({
                !SERCOM0.SPI.syncbusySWRST && !SERCOM0.SPI.softwareReset
            })
        case 12: SERCOM0.SPI.operatingMode = .host
        case 13: SERCOM0.SPI.dataOutPinout = .mosi2_sck3
        case 14: SERCOM0.SPI.dataInPinout = .miso1
        case 15: SERCOM0.SPI.chsize = 0
        case 16:
            SERCOM0.SPI.rxen = true
            _ = waitUntil({ !SERCOM0.SPI.syncbusyCTRLB })
        case 17: SERCOM0.SPI.cpol = (mode == .mode2 || mode == .mode3)
        case 18: SERCOM0.SPI.cpha = (mode == .mode1 || mode == .mode3)
        case 19: SERCOM0.SPI.dord = (dataOrder == .leastSignificantBitFirst)
        case 20: SERCOM0.SPI.baud = clockRateSelect.rawValue
            
        case 21:
            SERCOM0.SPI.enable = true
            _ = waitUntil({ !SERCOM0.SPI.syncbusyEnable })
        case 22:
            var drained: UInt32 = 0
            while SERCOM0.SPI.intFlagRXC && drained < 8 {
                _ = SERCOM0.SPI.data
                drained &+= 1
            }
        case 23: SERCOM0.SPI.intflagTXC = true
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
            if SERCOM0.SPI.intFlagDRE { break }
            i &+= 1
        }
        
        GPIO.PA04.setValue(.low)  // CS assert
        SERCOM0.SPI.data = UInt32(byte)
        
        var j: UInt32 = 0
        while j < 100_000 {
            if SERCOM0.SPI.intFlagRXC { break }
            j &+= 1
        }
        _ = SERCOM0.SPI.data  // drain RXC
        
        GPIO.PA04.setValue(.high)  // CS deassert
    }
    
    static func select() {
        GPIO.PA04.setValue(.low)
    }
    
    static func deselect() {
        GPIO.PA04.setValue(.high)
    }
    
    private static func applyMode(_ mode: Mode) {
        switch mode {
        case .mode0:
            SERCOM0.SPI.cpol = false
            SERCOM0.SPI.cpha = false
        case .mode1:
            SERCOM0.SPI.cpol = false
            SERCOM0.SPI.cpha = true
        case .mode2:
            SERCOM0.SPI.cpol = true
            SERCOM0.SPI.cpha = false
        case .mode3:
            SERCOM0.SPI.cpol = true
            SERCOM0.SPI.cpha = true
        }
    }
    
    private static func applyDataOrder(_ order: DataOrder) {
        SERCOM0.SPI.dord = (order == .leastSignificantBitFirst)
    }
    
//    @inline(__always)
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
