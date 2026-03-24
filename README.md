# SAMD21E 

## Requirements

- An Adafruit QT Py - SAMD21 Dev Board.

## How to build and run this example:

- Connect the Adafruit QT Py board via a USB cable to your Mac, and make sure it's in the USB Mass Storage firmware upload mode (either hold the BOOTSEL button while plugging the board, or make sure your Flash memory doesn't contain any valid firmware).
- Make sure you have a recent nightly Swift toolchain that has Embedded Swift support.
- Build and copy the program in the UF2 format to the Mass Storage device to trigger flashing the program into memory (after which the device will reboot and run the firmware):

``` console
$ cd SAMD21E
$ make
$ cp .build/Application.uf2 /Volumes/SAMD21E
```

- This is still in progress but I hope to have an example using an external LED that blinks as well as I would like to have an example using the oboard "NeoPixe" changing colors similar the the origional python example.
