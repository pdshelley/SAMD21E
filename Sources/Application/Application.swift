//
//  Minimal repro for swift#89287 (@inline(__always) hard fault on SAMD21).
//
//  Toggle: comment out the PA09 line in appInit() — board runs (LED blinks).
//  With it enabled: hard fault during GPIO.PA09.setDataDirection(.output).
//

var blinkTimer = PeriodicTimer(interval: 1000)
var ledState: DigitalValue = .low

func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkTimer.reset()

    GPIO.PA09.setDataDirection(.output)  // comment this line to avoid hard fault
    GPIO.PA09.setValue(.low)
}

func appMain() {
    if blinkTimer.hasElapsed() {
        ledState.toggle()
        GPIO.PA02.setValue(ledState)
    }
}
