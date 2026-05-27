//
//  I2C3.swift
//  SAMD21E
//
//  SERCOM3 I2C on STEMMA QT (PA16/PA17). Hardware access is in i2c3_master.c.
//

enum I2C3 {

    static let apds9999Address: UInt8 = 0x52
    static let apds9999PartIDRegister: UInt8 = 0x06
    static let apds9999ExpectedPartID: UInt8 = 0xC2

    /// True after C bring-up has initialized SERCOM3 I2C.
    static var isReady: Bool { i2c3_apds_sensor_ready() }

    static func readRGB() -> (red: UInt8, green: UInt8, blue: UInt8)? {
        guard isReady else { return nil }
        var r: UInt8 = 0
        var g: UInt8 = 0
        var b: UInt8 = 0
        guard i2c3_apds_read_rgb(&r, &g, &b) else { return nil }
        return (r, g, b)
    }
}
