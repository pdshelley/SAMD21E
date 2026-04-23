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
var userRowData: UInt32 = 42

// MARK: - Entry Points

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()
    userRowData = UserRowReader.loadWord()
    CDC.initialize()
}

func appMain() {
    CDC.task()

    // Print a greeting the first time a terminal opens the port
    let connected = CDC.isConnected
    if connected && !wasConnected {
        CDC.print("Hello from SAMD21E!\r\n")
        CDC.print("User Row: ")
        CDC.print(userRowData)
        CDC.print("\r\n")
    }
    wasConnected = connected

    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)

        if connected {
            CDC.print(ledState == .high ? "LED on\r\n" : "LED off\r\n")
        }
    }
}
