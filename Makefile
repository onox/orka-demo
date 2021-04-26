GLFW_LIBS := $(strip $(shell pkgconf --libs glfw3))
SIMD := $(shell ((gcc -march=native -dN -E - < /dev/null | grep -q "AVX2") && echo "AVX2") || echo "AVX")

X_GLFW_LIBS := -XORKA_GLFW_GLFW_LIBS="$(GLFW_LIBS)"
X_SIMD := -XORKA_SIMD_EXT="$(SIMD)"
SCENARIO_VARS = $(X_GLFW_LIBS) $(X_SIMD)

.PHONY: build clean

all: build
	mkdir -p results
	alr run -s

iris: build
	mkdir -p results
	GALLIUM_HUD=".c20frametime,primitives-generated,N primitives submitted,N vertex shader invocations,N fragment shader invocations" MESA_LOADER_DRIVER_OVERRIDE=iris alr run -s

build:
	alr build $(SCENARIO_VARS)

clean:
	alr clean
