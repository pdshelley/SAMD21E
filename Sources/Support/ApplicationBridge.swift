// C-callable entry points that forward to the Swift functions in Application.swift.
// Keeping @_cdecl here means Application.swift stays free of compiler annotations.

@_cdecl("app_init")
func _bridgeAppInit() { appInit() }

@_cdecl("app_main")
func _bridgeAppMain() { appMain() }
