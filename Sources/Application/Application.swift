//
//  Application.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//


// MARK: - State

var blinkTimer = PeriodicTimer(interval: 1000)
var ledState: DigitalValue = .low

// MARK: - Entry Points

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()
    
    // Milestone 1: route GCLK0 (DFLL48M @ 48 MHz) to USB, enable USB APB + AHB clocks.
    usbClockInit()
}

func appMain() {
    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)
    }
}
