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
var spiReady: Bool = false

private let spiBringUpDelayMs: UInt32 = 300

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

    if !spiReady && connected && UInt32(truncatingIfNeeded: millis()) >= spiBringUpDelayMs {
        if SPI0.configure() {
            spiReady = true
            CDC.print("SPI ready\r\n")
        } else {
            CDC.print("SPI configure not finished.\r\n")
        }
    }

    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)

        if connected {
            CDC.print(ledState == .high ? "LED on\r\n" : "LED off\r\n")
        }

        if spiReady {
            SPI0.transmit(ledState == .high ? 0xA5 : 0x5A)
        }
    }
}
