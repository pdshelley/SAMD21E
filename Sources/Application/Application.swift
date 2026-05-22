//
//  Application.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

// MARK: - State

var blinkTimer = PeriodicTimer(interval: 1000)
var ledState: DigitalValue = .low

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()
    
    // Code that breaks things
    GPIO.PA09.setDataDirection(.output)
    GPIO.PA09.setValue(.low)
}

func appMain() {
    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)
    }
}
