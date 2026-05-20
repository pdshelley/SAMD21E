//
//  Application.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

// MARK: - State

var blinkTimer = PeriodicTimer(interval: 1000)
var ledState: DigitalValue = .low
var wasConnected: Bool = false
//var spi0Ready: Bool = false
var spi1Ready: Bool = false

private let spiBringUpDelayMs: UInt32 = 300

// WS2812-over-SPI (Adafruit ZeroDMA style): 2.4 MHz SCK, 3 SPI bits per WS2812 bit.
//   0 → 100,  1 → 110  (MSB first on MOSI)
private var spiOutByte: UInt8 = 0
private var spiOutBitCount: UInt8 = 0

private func spiEmitBit(_ bit: UInt8) {
    spiOutByte = (spiOutByte << 1) | (bit & 1)
    spiOutBitCount += 1
    if spiOutBitCount == 8 {
        SPI1.transmitQueued(spiOutByte)
        spiOutBitCount = 0
        spiOutByte = 0
    }
}

private func spiEmitFlushPartial() {
    if spiOutBitCount > 0 {
        spiOutByte &<<= (8 - spiOutBitCount)
        SPI1.transmitQueued(spiOutByte)
        spiOutBitCount = 0
        spiOutByte = 0
    }
}

private func ws2812EmitBit(_ one: Bool) {
    spiEmitBit(1)
    spiEmitBit(one ? 1 : 0)
    spiEmitBit(0)
}

/// One GRB byte → 24 SPI bits (3 per WS2812 bit), MSB first.
private func ws2812TransmitByte(_ value: UInt8) {
    var bits = value
    for _ in 0..<8 {
        ws2812EmitBit((bits & 0x80) != 0)
        bits &<<= 1
    }
}

/// Clock out zero bytes so MOSI stays low for the WS2812 reset/latch (SPI idles high).
private func ws2812Latch() {
    for _ in 0..<32 {
        SPI1.transmitQueued(0)
    }
}

/// One onboard pixel, GRB order.
private func showNeoPixel(red: UInt8, green: UInt8, blue: UInt8) {
    spiOutByte = 0
    spiOutBitCount = 0
    ws2812TransmitByte(green)
    ws2812TransmitByte(red)
    ws2812TransmitByte(blue)
    spiEmitFlushPartial()
    ws2812Latch()
    SPI1.transmitFlush()
}

// MARK: - Entry Points

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()
    CDC.initialize()
}

func appMain() {
    CDC.task()

    let connected = CDC.isConnected
    if connected && !wasConnected {
        CDC.print("Hello from SAMD21E!\r\n")
    }
    wasConnected = connected
    
    if !spi1Ready && connected && UInt32(truncatingIfNeeded: millis()) >= spiBringUpDelayMs {
        if SPI1.configure() {
            spi1Ready = true
            CDC.print("SPI1 ready\r\n")
        } else {
            CDC.print("SPI1 configure not finished.\r\n")
        }
    }

//    if !spi0Ready && connected && UInt32(truncatingIfNeeded: millis()) >= spiBringUpDelayMs {
//        if SPI0.configure() {
//            spi0Ready = true
//            CDC.print("SPI0 ready\r\n")
//        } else {
//            CDC.print("SPI0 configure not finished.\r\n")
//        }
//    }

    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)

        if connected {
            CDC.print(ledState == .high ? "LED on\r\n" : "LED off\r\n")
        }

//        if spi0Ready {
//            SPI0.transmit(ledState == .high ? 0xA5 : 0x5A)
//        }

        if spi1Ready {
            if ledState == .high {
                showNeoPixel(red: 32, green: 0, blue: 0)
            } else {
                showNeoPixel(red: 0, green: 32, blue: 0)
            }
        }
    }
}
