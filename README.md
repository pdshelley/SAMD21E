# SAMD21 Embedded Swift — minimal hard-fault repro

Reproduces [swift#89287](https://github.com/swiftlang/swift/issues/89287): configuring GPIO PA09 can hard fault on SAMD21 bare metal.

Target: Adafruit QT Py SAMD21. LED on **A0** (PA02) blinks when the repro is disabled.

## Repro

Comment out one line in `appInit()`:

```swift
// GPIO.PA09.setDataDirection(.output)  // comment this line to avoid hard fault
```

With it enabled → hard fault during init. With it commented → LED blinks (coarse spin-loop timing).

## Build & flash

```bash
make clean && make
# double-tap reset, then:
tools/bossac/1.8.0-48-gb176eee/bossac -p cu.usbmodem1101 -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```

Requires Embedded Swift (`-enable-experimental-feature Embedded`).

## Sources

| File | Role |
|------|------|
| `Sources/Application/Application.swift` | GPIO layer + `app_init` / `app_main` + repro |
| `Sources/Support/boot.c` | Vectors, reset, 48 MHz clock, calls Swift |
| `Sources/Support/runtime.c` | MMIO shims + linker stubs |
| `Sources/Support/BridgingHeader.h` | C declarations for Swift |

One Swift file, two C files.
