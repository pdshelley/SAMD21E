# Embedded Swift example for the SAMD21E

Current stage: Simple blink, requires LED added to A0. Builds and uploads via USB with bossac. Built and tested with the Adafruit QT Py SAMD21.

## Build

```bash
# Clean and build
make clean && make
```

This produces: `..build/SAMD21E.bin` (correctly offset at 0x2000)

## Upload

1. **Double-tap the reset button** on the QT Py board quickly.
   - NeoPixel should stay steady green.
   - Board enters bootloader mode.

2. Upload with bossac (run immediately after double-tap):

```bash
tools/bossac/1.8.0-48-gb176eee/bossac -p cu.usbmodem1101 -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```

**Note:** The port (`cu.usbmodem1101`) may change. If you get "No device found", run this first to check:

```bash
ls /dev/cu.usbmodem*
```

Then update the `-p` value and retry the bossac command right after double-tapping reset.

## Full sequence (most common)

```bash
make clean && make
# Double-tap reset on QT Py
tools/bossac/1.8.0-48-gb176eee/bossac -p cu.usbmodem1101 -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```

Success: Board auto-resets and runs the sketch.
