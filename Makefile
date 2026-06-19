.DEFAULT_GOAL := build

CJPM = cjpm
CC = clang
AR = ar
RANLIB = ranlib
PYTHON_CONFIG ?= python3-config

BUILD_DIR := build
NATIVE_BUILD_DIR := $(BUILD_DIR)/native

NATIVE_BRIDGE_DIR := native/bridge
NATIVE_BRIDGE_SOURCE := $(NATIVE_BRIDGE_DIR)/python_bridge.c
NATIVE_BRIDGE_HEADER := $(NATIVE_BRIDGE_DIR)/python_bridge.h
NATIVE_BRIDGE_OBJECT := $(NATIVE_BUILD_DIR)/bridge/python_bridge.o
NATIVE_OBJECTS := $(NATIVE_BRIDGE_OBJECT)
NATIVE_LIB := $(NATIVE_BUILD_DIR)/libpython_bridge.a

SMOKE_DIR := tests/smoke
EXTERN_PRIMITIVE_TYPES_DIR := tests/extern_primitive_types
EXTERN_PRIMITIVE_TYPES_SUGARED_DIR := tests/extern_primitive_types_sugared
EXTERN_WITH_MODULES_1_DIR := tests/extern_with_modules_1
EXTERN_WITH_MODULES_1_SUGARED_DIR := tests/extern_with_modules_1_sugared
EXTERN_WITH_MODULES_2_DIR := tests/extern_with_modules_2
EXTERN_WITH_MODULES_2_SUGARED_DIR := tests/extern_with_modules_2_sugared

PYTHON_CFLAGS ?= $(shell $(PYTHON_CONFIG) --includes)
PYTHON_LDFLAGS ?= $(shell $(PYTHON_CONFIG) --ldflags --embed 2>/dev/null || $(PYTHON_CONFIG) --ldflags)
export PYTHON_LDFLAGS
COMMON_CFLAGS := -std=c11 -O2 -g -Wall -Wextra -Wno-unused-parameter
COMMON_CFLAGS += -Wno-missing-field-initializers -fwrapv -funsigned-char -D_GNU_SOURCE
COMMON_CFLAGS += $(PYTHON_CFLAGS)

ifeq ($(shell uname -s),Darwin)
COMMON_CFLAGS += -mmacosx-version-min=12.0
endif

.PHONY: all native cangjie build test smoke-build smoke-test extern-primitive-types-build extern-primitive-types-test extern-primitive-types-sugared-build extern-primitive-types-sugared-test extern-with-modules-1-build extern-with-modules-1-test extern-with-modules-1-sugared-build extern-with-modules-1-sugared-test extern-with-modules-2-build extern-with-modules-2-test extern-with-modules-2-sugared-build extern-with-modules-2-sugared-test clean

all: test

native: $(NATIVE_LIB)

cangjie: native
	$(CJPM) build

build: cangjie

test: build
	$(MAKE) smoke-test
	$(MAKE) extern-primitive-types-test
	$(MAKE) extern-primitive-types-sugared-test
	$(MAKE) extern-with-modules-1-test
	$(MAKE) extern-with-modules-1-sugared-test
	$(MAKE) extern-with-modules-2-test
	$(MAKE) extern-with-modules-2-sugared-test

smoke-build: native
	cd $(SMOKE_DIR) && $(CJPM) build

smoke-test: smoke-build
	cd $(SMOKE_DIR) && target/release/bin/main

extern-primitive-types-build: native
	cd $(EXTERN_PRIMITIVE_TYPES_DIR) && $(CJPM) build

extern-primitive-types-test: extern-primitive-types-build
	cd $(EXTERN_PRIMITIVE_TYPES_DIR) && target/release/bin/main

extern-primitive-types-sugared-build: native
	cd $(EXTERN_PRIMITIVE_TYPES_SUGARED_DIR) && $(CJPM) build

extern-primitive-types-sugared-test: extern-primitive-types-sugared-build
	cd $(EXTERN_PRIMITIVE_TYPES_SUGARED_DIR) && target/release/bin/main

extern-with-modules-1-build: native
	cd $(EXTERN_WITH_MODULES_1_DIR) && $(CJPM) build

extern-with-modules-1-test: extern-with-modules-1-build
	cd $(EXTERN_WITH_MODULES_1_DIR) && target/release/bin/main

extern-with-modules-1-sugared-build: native
	cd $(EXTERN_WITH_MODULES_1_SUGARED_DIR) && $(CJPM) build

extern-with-modules-1-sugared-test: extern-with-modules-1-sugared-build
	cd $(EXTERN_WITH_MODULES_1_SUGARED_DIR) && target/release/bin/main

extern-with-modules-2-build: native
	cd $(EXTERN_WITH_MODULES_2_DIR) && $(CJPM) build

extern-with-modules-2-test: extern-with-modules-2-build
	cd $(EXTERN_WITH_MODULES_2_DIR) && target/release/bin/main

extern-with-modules-2-sugared-build: native
	cd $(EXTERN_WITH_MODULES_2_SUGARED_DIR) && $(CJPM) build

extern-with-modules-2-sugared-test: extern-with-modules-2-sugared-build
	cd $(EXTERN_WITH_MODULES_2_SUGARED_DIR) && target/release/bin/main

clean:
	rm -rf $(BUILD_DIR) target
	rm -rf $(SMOKE_DIR)/target $(SMOKE_DIR)/build-script-cache
	rm -rf $(EXTERN_PRIMITIVE_TYPES_DIR)/target $(EXTERN_PRIMITIVE_TYPES_DIR)/build-script-cache
	rm -rf $(EXTERN_PRIMITIVE_TYPES_SUGARED_DIR)/target $(EXTERN_PRIMITIVE_TYPES_SUGARED_DIR)/build-script-cache
	rm -rf $(EXTERN_WITH_MODULES_1_DIR)/target $(EXTERN_WITH_MODULES_1_DIR)/build-script-cache
	rm -rf $(EXTERN_WITH_MODULES_1_SUGARED_DIR)/target $(EXTERN_WITH_MODULES_1_SUGARED_DIR)/build-script-cache
	rm -rf $(EXTERN_WITH_MODULES_2_DIR)/target $(EXTERN_WITH_MODULES_2_DIR)/build-script-cache
	rm -rf $(EXTERN_WITH_MODULES_2_SUGARED_DIR)/target $(EXTERN_WITH_MODULES_2_SUGARED_DIR)/build-script-cache

$(NATIVE_LIB): $(NATIVE_OBJECTS)
	mkdir -p $(@D)
	$(AR) rcs $@ $^
	$(RANLIB) $@

$(NATIVE_BRIDGE_OBJECT): $(NATIVE_BRIDGE_SOURCE) $(NATIVE_BRIDGE_HEADER)
	mkdir -p $(@D)
	$(CC) $(COMMON_CFLAGS) -c $< -o $@
