# Self-contained Makefile for Adafruit QT Py SAMD21 (M0) — pure C build.

PROJECT     := SAMD21E
BUILD_DIR   := build
TOOLCHAIN   := tools/arm-none-eabi-gcc/9-2019q4/bin
VARIANT_DIR := hardware/adafruit/samd/1.7.17/variants/qtpy_m0

CC      := $(TOOLCHAIN)/arm-none-eabi-gcc
OBJCOPY := $(TOOLCHAIN)/arm-none-eabi-objcopy
SIZE    := $(TOOLCHAIN)/arm-none-eabi-size

CFLAGS := \
  -mcpu=cortex-m0plus -mthumb \
  -g -Os -Werror=return-type \
  -ffunction-sections -fdata-sections \
  -nostdlib --param max-inline-insns-single=500 \
  -std=gnu11 \
  -DF_CPU=48000000L \
  -D__SAMD21E18A__ -DCRYSTALLESS \
  -DARM_MATH_CM0PLUS

INCLUDES := \
  -ISources/Support \
  -I$(VARIANT_DIR) \
  -Itools/CMSIS/5.4.0/CMSIS/Core/Include \
  -Itools/CMSIS-Atmel/1.2.2/CMSIS/Device/ATMEL

SUPPORT_SRCS := $(wildcard Sources/Support/*.c)
VARIANT_SRCS := $(VARIANT_DIR)/variant.c
SKETCH_SRCS  := Sources/Application/Application.c

ALL_SRCS := $(SUPPORT_SRCS) $(VARIANT_SRCS) $(SKETCH_SRCS)

OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(ALL_SRCS))

.PHONY: all clean

all: $(BUILD_DIR)/$(PROJECT).bin
	$(SIZE) -A $(BUILD_DIR)/$(PROJECT).elf

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/$(PROJECT).elf: $(OBJS)
	$(CC) -Os -Wl,--gc-sections \
		-Ttools/linker_scripts/gcc/flash_with_bootloader.ld \
		-Wl,--section-start=.text=0x2000 \
		-mcpu=cortex-m0plus -mthumb \
		--specs=nano.specs --specs=nosys.specs \
		-Wl,--cref -Wl,--check-sections -Wl,--gc-sections \
		-o $@ $^ \
		-Ltools/CMSIS/5.4.0/CMSIS/Lib/GCC/ -larm_cortexM0l_math -lm

$(BUILD_DIR)/$(PROJECT).bin: $(BUILD_DIR)/$(PROJECT).elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)
