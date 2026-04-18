//
//  BridgingHeader.h
//  SAMD21E
//
//  Created by Paul Shelley on 4/17/26.
//

#pragma once
#include <stdint.h>

// Millisecond delay backed by SysTick (delay.c)
extern void delay(unsigned long ms);
