#!/bin/bash

# Wrapper script to install ComfyUI custom nodes only
# This script calls the main custom nodes installer

# Function to show usage information
show_usage() {
    echo "Usage: $0 <COMFYUI_ROOT>"
    echo ""
    echo "Install ComfyUI custom nodes for an existing ComfyUI installation."
    echo ""
    echo "Arguments:"
    echo "  COMFYUI_ROOT    Path to the ComfyUI root directory (mandatory)"
    echo ""
    echo "Example:"
    echo "  $0 /path/to/ComfyUI"
    echo "  $0 ./ComfyUI"
}

# Check if ComfyUI root argument is provided or if help is requested
if [ $# -eq 0 ]; then
    echo "Error: ComfyUI root directory is required as a mandatory argument."
    echo ""
    show_usage
    exit 1
fi

# Handle help arguments
case "$1" in
    -h|--help|help)
        show_usage
        exit 0
        ;;
esac

# Get the ComfyUI root path from the first argument
COMFYUI_ROOT="$1"

# Get script directory for finding the main script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
MAIN_SCRIPT="$SCRIPT_DIR/scripts/install-custom-nodes.sh"

if [ -f "$MAIN_SCRIPT" ]; then
    bash "$MAIN_SCRIPT" "$COMFYUI_ROOT"
else
    echo "Error: Main custom nodes installer script not found at $MAIN_SCRIPT"
    exit 1
fi