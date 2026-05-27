//
//  Application.swift
//  SAMD21E
//
//  I2C/APDS + NeoPixel SPI/DMAC init in C (app_c_main_poll).
//  Swift: CDC, status LED blink, color loop → spi1_neopixel_set_rgb().
//

private var blinkTimer = PeriodicTimer(interval: 1000)
private var ledState: DigitalValue = .low
private var colorTimer = PeriodicTimer(interval: 200)
private var statusTimer = PeriodicTimer(interval: 3000)
func appInit() {
    blinkTimer.reset()
    colorTimer.reset()
    statusTimer.reset()
}

func appMain() {
    CDC.task()
    app_c_main_poll(UInt(truncatingIfNeeded: millis()))

    if app_c_color_loop_active() && app_c_may_configure_spi() {
        if colorTimer.hasElapsed() {
            colorTimer.reset()
            updateNeoPixelFromSensor()
        }
        if statusTimer.hasElapsed() {
            statusTimer.reset()
            printColorSample()
        }
    }

    if blinkTimer.hasElapsed() {
        ledState.toggle()
        app_c_status_led_toggle(ledState == .high)
    }
}

private func updateNeoPixelFromSensor() {
    var r: UInt8 = 0
    var g: UInt8 = 0
    var b: UInt8 = 0
    guard app_c_apds_read_rgb(&r, &g, &b) else { return }
    spi1_neopixel_set_rgb(r, g, b)
}

private func printColorSample() {
    var r: UInt8 = 0
    var g: UInt8 = 0
    var b: UInt8 = 0
    guard app_c_apds_read_rgb(&r, &g, &b) else {
        CDC.print("RGB read failed\r\n")
        return
    }
    CDC.print("RGB ")
    printHexByte(r)
    CDC.print(" ")
    printHexByte(g)
    CDC.print(" ")
    printHexByte(b)
    CDC.print("\r\n")
}

private func printHexByte(_ value: UInt8) {
    var nibbles: (UInt8, UInt8) = (hexDigit(value >> 4), hexDigit(value & 0x0F))
    _ = withUnsafePointer(to: &nibbles) { ptr in
        cdc_write(UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self), 2)
    }
    CDC.flush()
}

private func hexDigit(_ nibble: UInt8) -> UInt8 {
    let n = nibble & 0x0F
    if n < 10 { return 0x30 + n }
    return 0x41 + (n - 10)
}
