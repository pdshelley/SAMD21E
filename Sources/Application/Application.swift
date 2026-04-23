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
var userRowMAC: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0)
let shouldWriteMACAfterCDCConnect: Bool = false
let useCUserRowWriter: Bool = false
var didAttemptUserRowWrite: Bool = false
var userRowWriteSucceeded: Bool = false

// MARK: - Entry Points

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()
    userRowMAC = UserRowReader.loadMACAddress()
    CDC.initialize()
}

func appMain() {
    CDC.task()

    // Print a greeting the first time a terminal opens the port
    let connected = CDC.isConnected
    if connected && shouldWriteMACAfterCDCConnect && !didAttemptUserRowWrite {
        didAttemptUserRowWrite = true
        if useCUserRowWriter {
            userRowWriteSucceeded = user_row_write_mac_c(0xFA, 0x48, 0x37, 0x00, 0x00, 0x03)
        } else {
            userRowWriteSucceeded = UserRowWriter.writeMACAddress(0xFA, 0x48, 0x37, 0x00, 0x00, 0x03)
        }
        userRowMAC = UserRowReader.loadMACAddress()
    }
    if connected && !wasConnected {
        CDC.print("Hello from SAMD21E!\r\n")
        if didAttemptUserRowWrite {
            CDC.print(userRowWriteSucceeded ? "User Row write: OK\r\n" : "User Row write: FAIL\r\n")
        }
        CDC.print("User Row MAC: ")
        CDC.print(userRowMAC.0)
        CDC.print(":")
        CDC.print(userRowMAC.1)
        CDC.print(":")
        CDC.print(userRowMAC.2)
        CDC.print(":")
        CDC.print(userRowMAC.3)
        CDC.print(":")
        CDC.print(userRowMAC.4)
        CDC.print(":")
        CDC.print(userRowMAC.5)
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
