# Embedded Swift on SAMD21E

This project runs **Embedded Swift** on the [Adafruit QT Py SAMD21](https://www.adafruit.com/product/4600). It intended to follow the same pattern as Apple’s [swift-embedded-examples](https://github.com/swiftlang/swift-embedded-examples).

## What you need

### Required Hardware

| Item | Notes |
|------|--------|
| [Adafruit QT Py SAMD21](https://www.adafruit.com/product/4600) | Cortex-M0+, 256 KB flash, native USB |
| USB-C data cable | Must carry data, not charge-only |

### Optional Hardware

| Item | Notes |
|------|--------|
| LED  | The demo toggles **PA02** (pin **A0**). An external LED + resistor makes the blink easy to see |


## Quick Start: 

1. Install [`swift`](https://swift.org) using the [Install Embedded Swift](https://docs.swift.org/embedded/documentation/embedded/installembeddedswift) instructions.

2. Install [`uv`](https://github.com/astral-sh/uv), “an extremely fast Python package and project manager”, using the [uv installation instructions](https://docs.astral.sh/uv/getting-started/installation/).

3. Clone the source code. It’s recommended to use Git but you can do this however you would like. 
```bash
git clone https://github.com/pdshelley/SAMD21E.git
```
4. Change directory:
```bash
cd SAMD21E
```

5. Build

```bash
make clean && make
```

6. Find the correct USB modem.

```bash
ls /dev/cu.usbmodem*
```
You should see something like `/dev/cu.usbmodem21201` or `/dev/cu.usbmodem1101`

7. Double click the reset button to enter bootloader mode. The LED on the Adafruit QT Py SAMD21 should turn red and then green and stay green.

8. Flash the board
```bash
tools/bossac/1.8.0-48-gb176eee/bossac -p <your usb modem> -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```

Example: 

```bash
tools/bossac/1.8.0-48-gb176eee/bossac -p cu.usbmodem1101 -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```



## Connect with `screen` (serial monitor)

Some branches of this project (for example those with USB CDC / TinyUSB) print debug text over USB serial. On macOS you can read that with **`screen`**.


1. Flash and let the board run

After `bossac` finishes, the board reboots into **application mode** (not the green-bootloader state). Leave it plugged in.

2. Find the CDC port

```bash
ls /dev/cu.usbmodem*
```

Pick the port that appeared after the board reset into your app (often the same name as the bootloader port, but the board is in a different mode now).

3. Open the serial terminal

```bash
screen /dev/cu.usbmodem1101 115200
```

- **115200** is the conventional baud rate. USB CDC ignores baud on the wire, but `screen` still wants a number.
- You should see startup lines such as `Hello from SAMD21E!` on CDC-enabled builds.
- If nothing appears, press **Enter** once — some hosts wait for DTR before the device starts talking.

