//
//  Application.swift
//  SAMD21E
//
//  Swift stays minimal: LED blink + CDC.task(). I2C and USB-connect text run in C.
//

// MARK: - State

var blinkTimer = PeriodicTimer(interval: 1000)
var ledState: DigitalValue = .low

// MARK: - Entry Points

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()
    CDC.initialize()
}

func appMain() {
    CDC.task()

    let ms = UInt(truncatingIfNeeded: millis())
    app_c_main_poll(ms)

    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)
    }
}
