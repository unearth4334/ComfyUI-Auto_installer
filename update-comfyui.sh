#!/bin/bash

echo "=============================================================================="
echo "                    UmeAiRT ComfyUI Updater (Linux)"
echo "=============================================================================="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_FOLDER="$SCRIPT_DIR/scripts"
UPDATE_SCRIPT="$SCRIPTS_FOLDER/update-comfyui-main.sh"

echo "[INFO] Launching the ComfyUI update script..."
echo

# Check if the update script exists
if [ -f "$UPDATE_SCRIPT" ]; then
    chmod +x "$UPDATE_SCRIPT"
    bash "$UPDATE_SCRIPT" "$SCRIPT_DIR"
else
    echo "[ERROR] Update script not found: $UPDATE_SCRIPT"
    echo "[INFO] Please run the installer first to download all required scripts."
    exit 1
fi

echo
echo "[INFO] Update process completed."
read -p "Press Enter to continue..."