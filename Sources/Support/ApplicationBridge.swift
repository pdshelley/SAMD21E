//
//  ApplicationBridge.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

@_cdecl("app_init")
func _bridgeAppInit() { appInit() }

@_cdecl("app_main")
func _bridgeAppMain() { appMain() }
