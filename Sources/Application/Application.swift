// Minimal repro for swift#89287 — comment out the PA09 line in appInit() to avoid hard fault.

var blinkAt: UInt32 = 0
var ledState: DigitalValue = .low

@_cdecl("app_init")
func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
    blinkAt = UInt32(truncatingIfNeeded: millis())

    GPIO.PA09.setDataDirection(.output)  // comment this line to avoid hard fault
    GPIO.PA09.setValue(.low)
}

@_cdecl("app_main")
func appMain() {
    let now = UInt32(truncatingIfNeeded: millis())
    if now &- blinkAt >= 1000 {
        blinkAt &+= 1000
        ledState.toggle()
        GPIO.PA02.setValue(ledState)
    }
}
