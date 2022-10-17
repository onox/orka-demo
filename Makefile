.PHONY: build clean iris zink

all: build
	mkdir -p results
	alr run -s

iris:
	mkdir -p results
	GALLIUM_HUD=".c35frametime,primitives-generated,N primitives submitted,N vertex shader invocations,N fragment shader invocations" MESA_LOADER_DRIVER_OVERRIDE=iris alr run -s

zink:
	mkdir -p results
	GALLIUM_HUD=".c35frametime,primitives-generated,N primitives submitted,N vertex shader invocations,N fragment shader invocations" MESA_LOADER_DRIVER_OVERRIDE=zink alr run -s

build:
	alr build --release

clean:
	alr clean
