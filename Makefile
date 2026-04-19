# Self-contained Makefile for Adafruit QT Py SAMD21 (M0) — Embedded Swift build.

PROJECT   := SAMD21E
BUILD_DIR := .build
TOOLCHAIN := tools/arm-none-eabi-gcc/9-2019q4/bin

# C/C++ uses clang targeting ARM so the object format matches swiftc output
CC      := clang
OBJCOPY := $(TOOLCHAIN)/arm-none-eabi-objcopy
SIZE    := $(TOOLCHAIN)/arm-none-eabi-size
SWIFTC  := swiftc

TARGET_TRIPLE := armv6m-none-none-eabi

CFLAGS := \
  --target=$(TARGET_TRIPLE) \
  -mcpu=cortex-m0plus -mthumb \
  -mfloat-abi=soft \
  -fshort-enums \
  -g -Os \
  -ffunction-sections -fdata-sections \
  -nostdlib \
  -std=gnu11 \
  -DF_CPU=48000000L \
  -D__SAMD21E18A__ -DCRYSTALLESS \
  -DARM_MATH_CM0PLUS

INCLUDES := \
  -ISources/Support \
  -Itools/CMSIS/5.4.0/CMSIS/Core/Include \
  -Itools/CMSIS-Atmel/1.2.2/CMSIS/Device/ATMEL

SWIFT_FLAGS := \
  -target $(TARGET_TRIPLE) \
  -enable-experimental-feature Embedded \
  -wmo \
  -parse-as-library \
  -Osize \
  -import-bridging-header Sources/Support/BridgingHeader.h \
  $(foreach f,$(CFLAGS),-Xcc $(f)) \
  $(foreach f,$(INCLUDES),-Xcc $(f))

# C support files only (Application.swift replaces Application.c)
C_SRCS := $(wildcard Sources/Support/*.c)
C_OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(C_SRCS))

SWIFT_SRCS := \
  $(shell find Sources/Application -name "*.swift" 2>/dev/null) \
  $(shell find Sources/Support -name "*.swift" 2>/dev/null) \
  $(shell find Sources/SAMD21 -name "*.swift" 2>/dev/null)

SWIFT_OBJ := $(BUILD_DIR)/swift.o

ALL_OBJS := $(C_OBJS) $(SWIFT_OBJ)

.PHONY: all clean

all: $(BUILD_DIR)/$(PROJECT).bin
	$(SIZE) -A $(BUILD_DIR)/$(PROJECT).elf

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(SWIFT_OBJ): $(SWIFT_SRCS) Sources/Support/BridgingHeader.h | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(SWIFTC) $(SWIFT_FLAGS) -c $(SWIFT_SRCS) -o $@

# Link with arm-none-eabi-gcc so the bundled nano/nosys specs and linker script work
$(BUILD_DIR)/$(PROJECT).elf: $(ALL_OBJS)
	$(TOOLCHAIN)/arm-none-eabi-gcc -Os -Wl,--gc-sections \
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
