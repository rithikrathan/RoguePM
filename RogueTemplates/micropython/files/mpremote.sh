#!/bin/bash

# Check if a device is connected
DEVICE="/dev/ttyUSB0"  # Change to match your board
if [ ! -e "$DEVICE" ]; then
    echo "No MicroPython device found at $DEVICE"
    exit 1
fi

echo "Connecting to MicroPython REPL on $DEVICE..."
mpremote connect $DEVICE

