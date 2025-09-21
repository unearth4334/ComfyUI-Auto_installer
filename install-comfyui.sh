#!/bin/bash

# ============================================================================
# Section 1: Checking for root privileges (equivalent to Windows admin check)
# ============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "[INFO] This script requires root privileges for system package installation."
    echo "[INFO] Please run with sudo or as root user."
    exit 1
fi

# ============================================================================
# Section 2: Bootstrap downloader for all scripts
# ============================================================================

clear
echo "=============================================================================="
echo "                    UmeAiRT ComfyUI Installer (Linux)"
echo "=============================================================================="
echo "[OK] Root privileges confirmed."
echo

# Set the install path to the current directory (where the script is located)
INSTALL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_FOLDER="$INSTALL_PATH/scripts"
BOOTSTRAP_SCRIPT="$SCRIPTS_FOLDER/bootstrap-downloader.sh"

# GitHub URL for the bootstrap script
BOOTSTRAP_URL="https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/main/scripts/bootstrap-downloader.sh"

# Create scripts folder if it doesn't exist
if [ ! -d "$SCRIPTS_FOLDER" ]; then
    echo "[INFO] Creating the scripts folder: $SCRIPTS_FOLDER"
    mkdir -p "$SCRIPTS_FOLDER"
fi

# Download the bootstrap script
echo "[INFO] Downloading the bootstrap script..."
if command -v curl >/dev/null 2>&1; then
    curl -L "$BOOTSTRAP_URL" -o "$BOOTSTRAP_SCRIPT"
elif command -v wget >/dev/null 2>&1; then
    wget "$BOOTSTRAP_URL" -O "$BOOTSTRAP_SCRIPT"
else
    echo "[ERROR] Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Make the bootstrap script executable
chmod +x "$BOOTSTRAP_SCRIPT"

# Run the bootstrap script to download all other files
echo "[INFO] Running the bootstrap script to download all required files..."
bash "$BOOTSTRAP_SCRIPT" "$INSTALL_PATH"
echo "[OK] Bootstrap download complete."
echo

# ============================================================================
# Section 3: Running the main installation script
# ============================================================================

echo "[INFO] Launching the main installation script..."
echo

# Run the main installation script
MAIN_INSTALL_SCRIPT="$SCRIPTS_FOLDER/install-comfyui-main.sh"
if [ -f "$MAIN_INSTALL_SCRIPT" ]; then
    chmod +x "$MAIN_INSTALL_SCRIPT"
    bash "$MAIN_INSTALL_SCRIPT" "$INSTALL_PATH"
else
    echo "[ERROR] Main installation script not found: $MAIN_INSTALL_SCRIPT"
    exit 1
fi

echo
echo "[INFO] The script execution is complete."
read -p "Press Enter to continue..."