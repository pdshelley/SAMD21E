# Self-contained Makefile for Adafruit QT Py M0
# Top level: SAMD21E/

PROJECT   := SAMD21E
BUILD_DIR := build
CORE_DIR  := hardware/adafruit/samd/1.7.17
TOOLCHAIN := tools/arm-none-eabi-gcc/9-2019q4/bin
VARIANT   := qtpy_m0
NEO_DIR   := libraries/Adafruit_NeoPixel

CC      := $(TOOLCHAIN)/arm-none-eabi-gcc
CXX     := $(TOOLCHAIN)/arm-none-eabi-g++
OBJCOPY := $(TOOLCHAIN)/arm-none-eabi-objcopy
SIZE    := $(TOOLCHAIN)/arm-none-eabi-size

COMMON_FLAGS := -mcpu=cortex-m0plus -mthumb \
                -g -Os -Werror=return-type \
                -ffunction-sections -fdata-sections \
                -nostdlib --param max-inline-insns-single=500 \
                -DF_CPU=48000000L -DARDUINO=10607 \
                -DARDUINO_QTPY_M0 -DARDUINO_ARCH_SAMD -DARDUINO_SAMD_ADAFRUIT \
                -D__SAMD21E18A__ -DCRYSTALLESS -DADAFRUIT_QTPY_M0 \
                -DARM_MATH_CM0PLUS

CFLAGS   := $(COMMON_FLAGS) -std=gnu11
CXXFLAGS := $(COMMON_FLAGS) -std=gnu++11 -fno-threadsafe-statics -fno-rtti -fno-exceptions

INCLUDES := -I$(CORE_DIR)/cores/arduino \
            -I$(CORE_DIR)/variants/$(VARIANT) \
            -I$(CORE_DIR)/libraries/SPI \
            -I$(CORE_DIR)/libraries/Adafruit_ZeroDMA \
            -Itools/CMSIS/5.4.0/CMSIS/Core/Include \
            -Itools/CMSIS/5.4.0/CMSIS/DSP/Include \
            -Itools/CMSIS-Atmel/1.2.2/CMSIS/Device/ATMEL \
            -I$(NEO_DIR)

# All core sources - exclude USB to prevent USBDevice references
CORE_CPPS := $(filter-out $(CORE_DIR)/cores/arduino/USB/%.cpp,$(wildcard $(CORE_DIR)/cores/arduino/*.cpp))
CORE_CS   := $(filter-out $(CORE_DIR)/cores/arduino/USB/%.c,$(wildcard $(CORE_DIR)/cores/arduino/*.c))
VARIANT_CPP := $(CORE_DIR)/variants/$(VARIANT)/variant.cpp

LIB_CPPS  := $(wildcard $(NEO_DIR)/*.cpp)
LIB_CS    := $(wildcard $(NEO_DIR)/*.c)

# Objects
CORE_OBJS := $(patsubst $(CORE_DIR)/cores/arduino/%.cpp,$(BUILD_DIR)/core_%.o,$(CORE_CPPS)) \
             $(patsubst $(CORE_DIR)/cores/arduino/%.c,$(BUILD_DIR)/core_%.o,$(CORE_CS)) \
             $(BUILD_DIR)/variant.o

LIB_OBJS  := $(patsubst $(NEO_DIR)/%.cpp,$(BUILD_DIR)/neo_%.o,$(LIB_CPPS)) \
             $(patsubst $(NEO_DIR)/%.c,$(BUILD_DIR)/neo_%.o,$(LIB_CS)) \

SKETCH_CPP := $(BUILD_DIR)/$(PROJECT).ino.cpp
SKETCH_OBJ := $(BUILD_DIR)/$(PROJECT).ino.o

.PHONY: all clean

all: $(BUILD_DIR)/$(PROJECT).ino.bin
	$(SIZE) -A $(BUILD_DIR)/$(PROJECT).ino.elf

$(BUILD_DIR):
	mkdir -p $@
	
$(BUILD_DIR)/tiny_arduino:
	mkdir -p $@

$(SKETCH_CPP): $(PROJECT)/$(PROJECT).ino | $(BUILD_DIR)
	cp $< $@

$(SKETCH_OBJ): $(SKETCH_CPP) | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/core_%.o: $(CORE_DIR)/cores/arduino/%.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/core_%.o: $(CORE_DIR)/cores/arduino/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/variant.o: $(VARIANT_CPP) | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/neo_%.o: $(NEO_DIR)/%.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/neo_%.o: $(NEO_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD_DIR)/$(PROJECT).ino.elf: $(SKETCH_OBJ) $(CORE_OBJS) $(LIB_OBJS) | $(BUILD_DIR)
	$(CXX) -Os -Wl,--gc-sections \
		-T$(CORE_DIR)/variants/$(VARIANT)/linker_scripts/gcc/flash_with_bootloader.ld \
		-Wl,--section-start=.text=0x2000 \
		-mcpu=cortex-m0plus -mthumb --specs=nano.specs --specs=nosys.specs \
		-Wl,--cref -Wl,--check-sections -Wl,--gc-sections \
		-o $@ $^ \
		-Ltools/CMSIS/5.4.0/CMSIS/Lib/GCC/ -larm_cortexM0l_math -lm

$(BUILD_DIR)/$(PROJECT).ino.bin: $(BUILD_DIR)/$(PROJECT).ino.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -rf $(BUILD_DIR)
