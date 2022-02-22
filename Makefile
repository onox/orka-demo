SIMD := $(shell ((gcc -march=native -dN -E - < /dev/null | grep -q "AVX2") && echo "AVX2") || echo "AVX")

SCENARIO_VARS = -XORKA_SIMD_EXT="$(SIMD)"
RELEASE_VARS = -XORKA_COMPILE_CHECKS=none -XORKA_RUNTIME_CHECKS=none -XORKA_CONTRACTS=disabled
DEBUG_VARS = -XORKA_BUILD_MODE=debug -XORKA_DEBUG_SYMBOLS=enabled

ALR_BUILD = alr build -- $(SCENARIO_VARS)

.PHONY: build clean

all: build
	mkdir -p results
	alr run -s

iris:
	mkdir -p results
	GALLIUM_HUD=".c20frametime,primitives-generated,N primitives submitted,N vertex shader invocations,N fragment shader invocations" MESA_LOADER_DRIVER_OVERRIDE=iris alr run -s

build:
	$(ALR_BUILD) $(DEBUG_VARS)

clean:
	alr clean
