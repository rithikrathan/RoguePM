#!/bin/bash

# Bash script to upload code to the board

DEVICE="/dev/ttyUSB0"  # Change this based on your board
SRC_DIR="src/"  # Folder containing MicroPython scripts
FILES=("boot.py" "main.py" "config.py")  # List of files to upload

echo "Flashing files to MicroPython board..."

for file in "${FILES[@]}"; do
    if [ -f "$SRC_DIR/$file" ]; then
        echo "Uploading $file..."
        mpremote connect $DEVICE fs cp "$SRC_DIR/$file" ":/$file"
    else
        echo "Warning: $file not found in $SRC_DIR"
    fi
done

echo "Resetting board..."
mpremote connect $DEVICE reset

echo "Flash complete!"

