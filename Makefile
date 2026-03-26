##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift project authors.
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
##
##===----------------------------------------------------------------------===##

# Paths
REPOROOT         := $(shell pwd)
TOOLSROOT        := $(REPOROOT)/Tools
TOOLSET          := $(TOOLSROOT)/Toolsets/samd21e.json
MACHO2UF2        := $(TOOLSROOT)/macho2uf2.py
SWIFT_BUILD      := swift build
BUILD_SYSTEM     := native

# Flags
UF2_FAMILY       := samd21
ARCH             := armv6m
TARGET           := $(ARCH)-apple-none-macho
SWIFT_BUILD_ARGS := \
	--build-system $(BUILD_SYSTEM) \
	--configuration release \
	--triple $(TARGET) \
	--toolset $(TOOLSET) \
	--enable-experimental-prebuilts
BUILDROOT        := $(shell $(SWIFT_BUILD) $(SWIFT_BUILD_ARGS) --show-bin-path)

.PHONY: build
build:
	@echo "building..."
	$(SWIFT_BUILD) \
		$(SWIFT_BUILD_ARGS) \
		-Xlinker -map -Xlinker $(BUILDROOT)/Application.mangled.map \
		--verbose

	@echo "demangling linker map..."
	cat $(BUILDROOT)/Application.mangled.map \
		| c++filt | swift demangle > $(BUILDROOT)/Application.map

	@echo "disassembling..."
	otool \
		-arch $(ARCH) -v -V -d -t \
		$(BUILDROOT)/Application \
		| c++filt | swift demangle > $(BUILDROOT)/Application.disassembly

	@echo "extracting binary..."
	$(MACHO2UF2) \
		--uf2-family "$(UF2_FAMILY)" \
		"$(BUILDROOT)/Application" \
		"$(BUILDROOT)/Application.uf2" \
		--base-address 0x00002000 \
		--segments '__RESET,__VECTORS,__TEXT,__DATA'

.PHONY: clean
clean:
	@echo "cleaning..."
	@swift package clean
	@rm -rf .build
