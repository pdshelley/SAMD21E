# Embedded Swift on Adafruit QT Py SAMD21

This project runs **Embedded Swift** on the [Adafruit QT Py SAMD21](https://www.adafruit.com/product/4603) — a small ARM Cortex-M0+ board — without an Arduino or CircuitPython runtime. It follows the same idea as Apple’s [swift-embedded-examples](https://github.com/swiftlang/swift-embedded-examples): bare-metal firmware written mostly in Swift, with a thin C boot layer.

**Platform:** macOS. The build is tested on Mac and bundles the ARM GCC linker/tools in `tools/`. Other platforms may work with effort, but are not documented here yet.

## What you need

### Hardware

| Item | Notes |
|------|--------|
| [Adafruit QT Py SAMD21](https://www.adafruit.com/product/4603) | Cortex-M0+, 256 KB flash, native USB |
| USB-C data cable | Must carry data, not charge-only |
| LED on **A0** (optional but recommended) | The demo toggles **PA02** (pin **A0**). An external LED + resistor makes the blink easy to see |

### Software (macOS)

- **Xcode Command Line Tools** — provides `clang`, used to compile the C support files:

  ```bash
  xcode-select --install
  ```

- **Terminal** — Terminal.app or iTerm. Serial monitoring uses the built-in `screen` command (no extra install).

Everything else (ARM GCC, `bossac` flasher, CMSIS headers) is **included in this repo** under `tools/`.

## Get the code

```bash
git clone https://github.com/pdshelley/SAMD21E.git
cd SAMD21E
```

## Build the firmware

1. Install [`swift`](https://swift.org) using the [Install Embedded Swift](https://docs.swift.org/embedded/documentation/embedded/installembeddedswift) instructions.

   On macOS this usually means downloading a **Development Snapshot** from [swift.org/download](https://swift.org/download/), installing the `.pkg` toolchain, then selecting it when you build:

   ```bash
   TOOLCHAINS=swift swiftc --version
   ```

   You should see a **development snapshot** (not only the Xcode-bundled release Swift). Embedded Swift is enabled in our Makefile with `-enable-experimental-feature Embedded`.

2. Install [`uv`](https://github.com/astral-sh/uv), “an extremely fast Python package and project manager”, using the [uv installation instructions](https://docs.astral.sh/uv/getting-started/installation/).

   On macOS, the standalone installer is:

   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

   Then confirm it is on your `PATH`:

   ```bash
   uv --version
   ```

> **Is `uv` required for *this* repo?**  
> **Embedded Swift (step 1) — yes.** Our firmware will not build without it.  
> **`uv` (step 2) — no, not for `make` today.** Apple lists it because many projects in [swift-embedded-examples](https://github.com/swiftlang/swift-embedded-examples) use Python helpers managed by `uv` (see [swift-embedded-examples#95](https://github.com/swiftlang/swift-embedded-examples/pull/95)). This SAMD21 project uses a plain `Makefile` and does not call `uv` or any Python scripts. Install it anyway if you are also working through Apple’s examples, or if we add Python tooling later.

3. **Compile** the firmware from the project root:

   ```bash
   make clean && TOOLCHAINS=swift make
   ```

   Or use the helper script (same thing):

   ```bash
   ./scripts/local-build.sh
   ```

   On success you get:

   - `.build/SAMD21E.bin` — binary to flash
   - `.build/SAMD21E.elf` — for debugging/size inspection

   **Common build error:** `unable to load standard library for target 'armv6m-none-none-eabi'`

   That means plain Xcode Swift was used instead of the Embedded Swift snapshot. Always prefix with `TOOLCHAINS=swift` or run `./scripts/local-build.sh`.

## Flash the board

The QT Py ships with a USB bootloader. You upload with **bossac** (bundled in `tools/bossac/`).

### Step 1 — Enter bootloader mode

1. Plug the QT Py into your Mac with USB-C.
2. **Double-tap the RESET button** quickly (two taps within ~½ second).
3. The onboard **NeoPixel should turn red and then solid green**. The board is now in bootloader mode.

### Step 2 — Find the correct `usbmodem` port

macOS exposes the QT Py as `/dev/cu.usbmodem*` (and matching `/dev/tty.usbmodem*`). **Always use the `cu.` device** with `bossac` and `screen` — not `tty.`.

1. **Unplug the board**, then list existing ports (optional baseline):

   ```bash
   ls /dev/cu.usbmodem* 2>/dev/null || echo "(none yet)"
   ```

2. **Plug in the QT Py** with USB-C, then **double-tap RESET** so the NeoPixel is **solid green** (bootloader mode).

3. **List ports again** immediately:

   ```bash
   ls /dev/cu.usbmodem*
   ```

   Example output:

   ```text
   /dev/cu.usbmodem1101
   ```

4. **Pick the port name for `bossac`:**
   - If you see **one** `cu.usbmodem*` entry, use that — e.g. `cu.usbmodem1101`.
   - If you see **several**, unplug the QT Py, run `ls` again, plug it back in, double-tap RESET, and run `ls` again — the **new** name is your board.
   - Pass only the device name to `bossac`, **without** `/dev/` — e.g. `-p cu.usbmodem1101`.

5. **If `ls` shows nothing:**
   - Try a different USB cable (must be data-capable, not charge-only).
   - Double-tap RESET again — green NeoPixel means bootloader is active; you have ~8 seconds to flash.
   - Quit any app that might hold the port (`screen`, Arduino Serial Monitor, etc.), then run `ls` again.

The number in the port name (`1101`, `101`, etc.) **changes** when you unplug, replug, or switch between bootloader and app mode. Run `ls /dev/cu.usbmodem*` again every time before flashing.

### Step 3 — Upload

Replace `cu.usbmodem1101` with your port from step 2:

```bash
tools/bossac/1.8.0-48-gb176eee/bossac \
  -p cu.usbmodem1101 \
  -e -w -v -R \
  --offset=0x2000 \
  .build/SAMD21E.bin
```

| Flag | Meaning |
|------|---------|
| `-p` | Serial port (no `/dev/` prefix) |
| `-e` | Erase flash |
| `-w` | Write firmware |
| `-R` | Reset and run after upload |
| `--offset=0x2000` | Skip the 8 KB bootloader region |

The board resets and runs your firmware when upload finishes.

### Full build-and-flash sequence

```bash
make clean && TOOLCHAINS=swift make
# Double-tap RESET — NeoPixel green
ls /dev/cu.usbmodem*
tools/bossac/1.8.0-48-gb176eee/bossac -p cu.usbmodem1101 -e -w -v -R --offset=0x2000 .build/SAMD21E.bin
```

## Connect with `screen` (serial monitor)

Some branches of this project (for example those with USB CDC / TinyUSB) print debug text over USB serial. On macOS you can read that with **`screen`**.

> **Note:** The current minimal `feature/hardfault` branch blinks an LED only — it has no USB serial output. Use `screen` on branches that include USB CDC (e.g. `feature/I2C`, `feature/NeoPixel_CDC`). The steps below are the same for any CDC-enabled build.

### Step 1 — Flash and let the board run

After `bossac` finishes, the board reboots into **application mode** (not the green-bootloader state). Leave it plugged in.

### Step 2 — Find the CDC port

```bash
ls /dev/cu.usbmodem*
```

Pick the port that appeared after the board reset into your app (often the same name as the bootloader port, but the board is in a different mode now).

### Step 3 — Open the serial terminal

```bash
screen /dev/cu.usbmodem1101 115200
```

- **115200** is the conventional baud rate. USB CDC ignores baud on the wire, but `screen` still wants a number.
- You should see startup lines such as `Hello from SAMD21E!` on CDC-enabled builds.
- If nothing appears, press **Enter** once — some hosts wait for DTR before the device starts talking.

### Step 4 — Quit `screen`

`screen` keeps running until you detach:

1. Press **Ctrl-A**
2. Then **K**
3. Then **Y** to confirm

Or: **Ctrl-A** then **\\** and confirm.

### Serial troubleshooting

| Problem | What to try |
|---------|-------------|
| `Resource busy` | Another program has the port open. Quit `screen`, Arduino IDE Serial Monitor, CoolTerm, etc. |
| No output | Confirm you flashed a **CDC-enabled** build; replug USB; run `ls /dev/cu.usbmodem*` again |
| Garbled text | Wrong baud is rare on USB CDC; replug and reopen `screen` at `115200` |
| Need to re-flash | **Close `screen` first**, then double-tap RESET for green bootloader and run `bossac` again |

## What the firmware does (this branch)

This branch is a **minimal Embedded Swift** demo that also reproduces [swift#89287](https://github.com/swiftlang/swift/issues/89287): configuring GPIO **PA09** can hard-fault on SAMD21 bare metal.

| Signal | Pin | Behavior |
|--------|-----|----------|
| Status LED | **A0** / **PA02** | Blinks when the repro is **disabled** |
| Repro pin | **PA09** | Enabling output on this pin triggers a hard fault |

In `Sources/Application/Application.swift`, comment out the PA09 lines in `appInit()` to get a steady blink:

```swift
// GPIO.PA09.setDataDirection(.output)  // comment this line to avoid hard fault
// GPIO.PA09.setValue(.low)
```

With those lines **enabled** → hard fault during init. With them **commented** → LED on A0 blinks (coarse spin-loop timing).

## Project layout

| Path | Role |
|------|------|
| `Sources/Application/Application.swift` | App logic: GPIO, `app_init`, `app_main` |
| `Sources/Support/boot.c` | Reset vector, 48 MHz clock init, calls into Swift |
| `Sources/Support/runtime.c` | MMIO helpers and linker stubs for Embedded Swift |
| `Sources/Support/BridgingHeader.h` | C declarations imported into Swift |
| `Makefile` | Build: `clang` for C, `swiftc -enable-experimental-feature Embedded` for Swift |
| `tools/arm-none-eabi-gcc/` | Cross linker and binutils |
| `tools/bossac/` | SAMD21 USB bootloader flasher |
| `tools/linker_scripts/` | Flash layout (app starts at `0x2000`) |

## Learn more about Embedded Swift

This repo is a sibling spirit to Apple’s official examples, not a copy of them:

- [swift-embedded-examples](https://github.com/swiftlang/swift-embedded-examples) — catalog of bare-metal and SDK-based demos
- [Embedded Swift documentation](https://docs.swift.org/embedded/documentation/embedded/)
- [Embedded Swift vision](https://github.com/swiftlang/swift-evolution/blob/main/visions/embedded-swift.md)
- [Swift forums: Embedded Swift](https://forums.swift.org/t/embedded-swift/67057)

Apple’s examples often use `make` plus platform-specific upload tools (UF2, `st-flash`, etc.). This project uses **Make + bossac** for the QT Py SAMD21 — the same “one Makefile, one binary” pattern as examples like [stm32-blink](https://github.com/swiftlang/swift-embedded-examples/tree/main/stm32-blink) or [rpi-pico-blink](https://github.com/swiftlang/swift-embedded-examples/tree/main/rpi-pico-blink).

## License

See repository license files. Third-party tools (CMSIS, bossac, etc.) live under `tools/` with their own licenses.
