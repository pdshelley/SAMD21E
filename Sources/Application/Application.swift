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
var spi1Ready: Bool = false

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

    if !spi1Ready && UInt32(truncatingIfNeeded: millis()) >= spiBringUpDelayMs {
        if SPI1.configure() {
            spi1Ready = true
            if connected {
                CDC.print("SPI1 ready\r\n")
            }
        } else if connected {
            CDC.print("SPI1 configure not finished.\r\n")
        }
    }

    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)

        if connected {
            CDC.print(ledState == .high ? "LED on\r\n" : "LED off\r\n")
        }

        if spi1Ready {
            if ledState == .high {
                SPI1.transmitNeoPixel(red: 0, green: 0, blue: 50)
            } else {
                SPI1.transmitNeoPixel(red: 50, green: 0, blue: 0)
            }
        }
    }
}
