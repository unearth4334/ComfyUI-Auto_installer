#!/bin/bash

echo "Activating ComfyUI virtual environment..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate the virtual environment
# Linux uses bin/activate instead of Scripts/activate.bat
source "$SCRIPT_DIR/ComfyUI/venv/bin/activate"

echo "Starting ComfyUI with custom arguments..."

# Move to the ComfyUI folder
cd "$SCRIPT_DIR/ComfyUI"

# Prepare the base path
BASE_DIR="$SCRIPT_DIR"
TMP_DIR="$SCRIPT_DIR/ComfyUI/temp"

echo "Launching Python script..."
# Run the Python script with the specified arguments
python main.py --use-sage-attention --disable-smart-memory --base-directory "$BASE_DIR" --auto-launch --temp-directory "$TMP_DIR"

# Wait for user input before closing (equivalent to pause in batch)
read -p "Press Enter to continue..."