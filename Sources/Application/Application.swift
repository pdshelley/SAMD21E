//
//  Application.swift
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//


func appInit() {
    GPIO.PA02.setDataDirection(.output)
    GPIO.PA02.setValue(.low)
}

func appMain() {
    GPIO.PA02.setValue(.high)
    delay(1000)
    GPIO.PA02.setValue(.low)
    delay(1000)
}
