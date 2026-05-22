# SAMD21 Embedded Swift — minimal hard-fault repro

Reproduces [swift#89287](https://github.com/swiftlang/swift/issues/89287): `@inline(__always)` on SAMD21 bare metal can trigger a hard fault when configuring GPIO PA09.

Target: Adafruit QT Py SAMD21. LED on **A0** (PA02) blinks when the repro is disabled.

## Repro

1. Build and flash (see below).
2. With the default `Application.swift`, the board **hard faults** during `appInit()`.
3. **Comment out one line** in `appInit()` to get a working build:

```swift
// GPIO.PA09.setDataDirection(.output)  // comment this line to avoid hard fault
```

The LED on A0 should then blink once per second.

The original SPI-path report also involved `@inline(__always)` on byte-level GPIO helpers; this minimal project triggers via `setDataDirection` on PA09 without SPI or USB.

## Build

```bash
make clean && make
```

Produces `.build/SAMD21E.bin` (flash offset `0x2000`).

Requires an Embedded Swift toolchain (e.g. `main-snapshot-2026-05-17` or later nightly with `-enable-experimental-feature Embedded`).

## Upload

1. Double-tap reset on the QT Py (NeoPixel steady green = bootloader).
2. Flash with bossac (adjust the port if needed):

```bash
ls /dev/cu.usbmodem*
tools/bossac/1.8.0-48-gb176eee/bossac -p cu.usbmodem1101 -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```

## Layout

| Path | Role |
|------|------|
| `Sources/Application/Application.swift` | `app_init` / `app_main`, repro toggle, LED blink |
| `Sources/SAMD21/GPIO.swift` | PORT A registers, pin types, `DigitalValue` |
| `Sources/Support/boot.c` | Vector table, reset, SysTick, `millis()`, calls Swift `app_init` / `app_main` |
| `Sources/Support/startup.c` | 48 MHz clock init (required before GPIO is reliable) |
| `Sources/Support/runtime.c` | Volatile MMIO shims, stack guard, libatomic stubs for the linker |

Two Swift files, three C files. USB, TinyUSB, SPI, and SERCOM code have been removed.
