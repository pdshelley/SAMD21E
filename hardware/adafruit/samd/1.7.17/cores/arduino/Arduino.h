/*
  Arduino.h - Minimal main include for SAMD21 (QT Py M0) core.
*/

#ifndef Arduino_h
#define Arduino_h

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* CMSIS device header (SAMD21 + Atmel) */
#include "sam.h"

/* Pin mode / digital I/O constants used by the sketch + NeoPixel */
#include "wiring_constants.h"

#define clockCyclesPerMicrosecond() ( SystemCoreClock / 1000000L )
#define clockCyclesToMicroseconds(a) ( ((a) * 1000L) / (SystemCoreClock / 1000L) )
#define microsecondsToClockCycles(a) ( (a) * (SystemCoreClock / 1000000L) )

/* System init + Arduino entry shape */
int  main( void );
void init( void );
void yield( void );

/* User sketch hooks */
void setup( void );
void loop( void );

/* Pin description struct + g_APinDescription */
#include "WVariant.h"

#ifdef __cplusplus
} /* extern "C" */
#endif

/* SAMD21 timing / delay / basic digital I/O */
#include "delay.h"
#include "variant.h"
#include "wiring.h"
#include "wiring_digital.h"

#define interrupts()   __enable_irq()
#define noInterrupts() __disable_irq()

#endif /* Arduino_h */
