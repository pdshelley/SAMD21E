//
//  ApplicationBridge.swift
//  SAMD21E
//
//  Minimal Embedded Swift entry: all hardware and the main loop live in C.
//

@_cdecl("app_init")
func _bridgeAppInit() {
    app_c_platform_init()
}

@_cdecl("app_main")
func _bridgeAppMain() {
    app_c_main_poll(UInt(truncatingIfNeeded: millis()))
}
