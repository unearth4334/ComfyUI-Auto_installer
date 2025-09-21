#!/bin/bash

# Wrapper script to install ComfyUI custom nodes only
# This script calls the main custom nodes installer

# Function to show usage information
show_usage() {
    echo "Usage: $0 <COMFYUI_ROOT> [--venv-path <VENV_PATH>]"
    echo ""
    echo "Install ComfyUI custom nodes for an existing ComfyUI installation."
    echo ""
    echo "Arguments:"
    echo "  COMFYUI_ROOT              Path to the ComfyUI root directory (mandatory)"
    echo ""
    echo "Options:"
    echo "  --venv-path <VENV_PATH>   Path to Python virtual environment executable"
    echo "                            (default: <COMFYUI_ROOT>/venv/bin/python)"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/ComfyUI"
    echo "  $0 ./ComfyUI"
    echo "  $0 /path/to/ComfyUI --venv-path /custom/venv/bin/python"
}

# Initialize variables
COMFYUI_ROOT=""
CUSTOM_VENV_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        --venv-path)
            if [ -z "$2" ] || [[ $2 == --* ]]; then
                echo "Error: --venv-path requires a path argument."
                echo ""
                show_usage
                exit 1
            fi
            CUSTOM_VENV_PATH="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$COMFYUI_ROOT" ]; then
                COMFYUI_ROOT="$1"
            else
                echo "Error: Unexpected argument '$1'"
                echo ""
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if ComfyUI root argument is provided
if [ -z "$COMFYUI_ROOT" ]; then
    echo "Error: ComfyUI root directory is required as a mandatory argument."
    echo ""
    show_usage
    exit 1
fi

# Get script directory for finding the main script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
MAIN_SCRIPT="$SCRIPT_DIR/scripts/install-custom-nodes.sh"

if [ -f "$MAIN_SCRIPT" ]; then
    if [ -n "$CUSTOM_VENV_PATH" ]; then
        bash "$MAIN_SCRIPT" "$COMFYUI_ROOT" --venv-path "$CUSTOM_VENV_PATH"
    else
        bash "$MAIN_SCRIPT" "$COMFYUI_ROOT"
    fi
else
    echo "Error: Main custom nodes installer script not found at $MAIN_SCRIPT"
    exit 1
fi