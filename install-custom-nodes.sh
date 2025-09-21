#!/bin/bash

# Wrapper script to install ComfyUI custom nodes only
# This script calls the main custom nodes installer

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
MAIN_SCRIPT="$SCRIPT_DIR/scripts/install-custom-nodes.sh"

if [ -f "$MAIN_SCRIPT" ]; then
    bash "$MAIN_SCRIPT" "$SCRIPT_DIR"
else
    echo "Error: Main custom nodes installer script not found at $MAIN_SCRIPT"
    exit 1
fi