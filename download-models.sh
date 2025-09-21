#!/bin/bash

show_menu() {
    clear
    echo "================================================="
    echo
    echo "           UmeAiRT Model Downloader Menu"
    echo
    echo "================================================="
    echo
    echo "  Choose model to download:"
    echo
    echo "    1. FLUX Models"
    echo "    2. WAN2.1 Models"
    echo "    3. WAN2.2 Models"
    echo "    4. HIDREAM Models"
    echo "    5. LTXV Models"
    echo "    6. QWEN Models"
    echo
    echo "    q. Quit"
    echo
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while true; do
    show_menu
    read -p "Your choice: " CHOICE
    
    case $CHOICE in
        1)
            echo "Starting download of FLUX models..."
            bash "$SCRIPT_DIR/scripts/download-flux-models.sh" "$SCRIPT_DIR"
            ;;
        2)
            echo "Starting download of WAN 2.1 models..."
            bash "$SCRIPT_DIR/scripts/download-wan2.1-models.sh" "$SCRIPT_DIR"
            ;;
        3)
            echo "Starting download of WAN 2.2 models..."
            bash "$SCRIPT_DIR/scripts/download-wan2.2-models.sh" "$SCRIPT_DIR"
            ;;
        4)
            echo "Starting download of HIDREAM models..."
            bash "$SCRIPT_DIR/scripts/download-hidream-models.sh" "$SCRIPT_DIR"
            ;;
        5)
            echo "Starting download of LTXV models..."
            bash "$SCRIPT_DIR/scripts/download-ltxv-models.sh" "$SCRIPT_DIR"
            ;;
        6)
            echo "Starting download of QWEN models..."
            bash "$SCRIPT_DIR/scripts/download-qwen-models.sh" "$SCRIPT_DIR"
            ;;
        q|Q)
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac
    
    echo
    echo "The download script is complete."
    read -p "Press Enter to continue..."
done