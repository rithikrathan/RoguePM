# The specific CLI command for the Processing Snap package
PROC_CLI := processing cli
FFMPEG   := ffmpeg

# Paths
SKETCH_DIR  := $(shell pwd)
SKETCH_NAME := $(shell basename $(SKETCH_DIR))
BUILD_DIR   := $(SKETCH_DIR)/build
FRAME_DIR   := $(SKETCH_DIR)/videoFrames
VIDEO_OUT   := $(SKETCH_NAME).mp4

FPS := 60

.PHONY: all run video clean dirs

all: run video

run: dirs
	@echo "Running Sketch via Snap CLI..."
	$(PROC_CLI) --sketch="$(SKETCH_DIR)" --output="$(BUILD_DIR)" --force --run

dirs:
	@mkdir -p "$(BUILD_DIR)"
	@mkdir -p "$(FRAME_DIR)"

video:
	@if [ ! -d "$(FRAME_DIR)" ] || [ -z "$$(ls -A $(FRAME_DIR) 2>/dev/null)" ]; then \
		echo "Error: No frames found in $(FRAME_DIR). check your saveFrame() path."; \
		exit 1; \
	fi
	@echo "Stitching frames into $(VIDEO_OUT)..."
	$(FFMPEG) -y -framerate $(FPS) -i "$(FRAME_DIR)/frame-%08d.png" \
		-c:v libx264 -pix_fmt yuv420p -crf 18 "$(VIDEO_OUT)"

clean:
	rm -rf "$(BUILD_DIR)"
	rm -f "$(FRAME_DIR)"/*.png
