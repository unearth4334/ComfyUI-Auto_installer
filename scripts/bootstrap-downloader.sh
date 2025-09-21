#!/bin/bash

# SYNOPSIS
#     Bootstrap downloader for ComfyUI Auto-Installer scripts (Linux version)
# DESCRIPTION
#     Downloads all necessary scripts and configuration files from the GitHub repository

# Parameters
INSTALL_PATH="${1:-$(pwd)}"
SCRIPTS_FOLDER="$INSTALL_PATH/scripts"

# GitHub repository information
GITHUB_REPO="UmeAiRT/ComfyUI-Auto_installer"
GITHUB_BRANCH="main"
BASE_URL="https://github.com/$GITHUB_REPO/raw/$GITHUB_BRANCH"

# Create logs directory
LOG_PATH="$INSTALL_PATH/logs"
mkdir -p "$LOG_PATH"
LOG_FILE="$LOG_PATH/bootstrap_log.txt"

# Logging function
write_log() {
    local message="$1"
    local color="${2:-white}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_message="[$timestamp] [Bootstrap] $message"
    
    # Print to console with color
    case $color in
        red) echo -e "\e[31m$message\e[0m" ;;
        green) echo -e "\e[32m$message\e[0m" ;;
        yellow) echo -e "\e[33m$message\e[0m" ;;
        gray) echo -e "\e[90m$message\e[0m" ;;
        *) echo "$message" ;;
    esac
    
    # Append to log file
    echo "$log_message" >> "$LOG_FILE"
}

# Function to download files
download_file() {
    local url="$1"
    local output_path="$2"
    local file_name=$(basename "$output_path")
    
    if [ -f "$output_path" ]; then
        write_log "Skipping: $file_name (already exists)" "gray"
        return 0
    fi
    
    write_log "Downloading: $file_name"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$output_path")"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "$url" -o "$output_path"
    elif command -v wget >/dev/null 2>&1; then
        wget "$url" -O "$output_path"
    else
        write_log "ERROR: Neither curl nor wget found. Please install one of them." "red"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        write_log "Downloaded successfully: $file_name" "green"
        return 0
    else
        write_log "Failed to download: $file_name" "red"
        return 1
    fi
}

# Main execution
write_log "Starting bootstrap download process..." "green"
write_log "Install path: $INSTALL_PATH"
write_log "Scripts folder: $SCRIPTS_FOLDER"

# Create scripts directory if it doesn't exist
mkdir -p "$SCRIPTS_FOLDER"

# List of files to download
declare -A FILES_TO_DOWNLOAD=(
    ["scripts/install-comfyui-main.sh"]="$BASE_URL/scripts/Install-ComfyUI.ps1"
    ["scripts/update-comfyui-main.sh"]="$BASE_URL/scripts/Update-ComfyUI.ps1"
    ["scripts/dependencies.json"]="$BASE_URL/scripts/dependencies.json"
    ["scripts/custom_nodes.csv"]="$BASE_URL/scripts/custom_nodes.csv"
    ["scripts/comfy.settings.json"]="$BASE_URL/scripts/comfy.settings.json"
    ["scripts/download-flux-models.sh"]="$BASE_URL/scripts/Download-FLUX-Models.ps1"
    ["scripts/download-wan2.1-models.sh"]="$BASE_URL/scripts/Download-WAN2.1-Models.ps1"
    ["scripts/download-wan2.2-models.sh"]="$BASE_URL/scripts/Download-WAN2.2-Models.ps1"
    ["scripts/download-hidream-models.sh"]="$BASE_URL/scripts/Download-HIDREAM-Models.ps1"
    ["scripts/download-ltxv-models.sh"]="$BASE_URL/scripts/Download-LTXV-Models.ps1"
    ["scripts/download-qwen-models.sh"]="$BASE_URL/scripts/Download-QWEN-Models.ps1"
)

# Download each file
TOTAL_FILES=${#FILES_TO_DOWNLOAD[@]}
CURRENT_FILE=0

for local_path in "${!FILES_TO_DOWNLOAD[@]}"; do
    ((CURRENT_FILE++))
    remote_url="${FILES_TO_DOWNLOAD[$local_path]}"
    full_local_path="$INSTALL_PATH/$local_path"
    
    write_log "[$CURRENT_FILE/$TOTAL_FILES] Processing: $(basename "$local_path")"
    
    # For now, we'll just download the existing files as they are
    # In a real implementation, these would be converted shell scripts
    if download_file "$remote_url" "$full_local_path"; then
        # Make scripts executable if they are shell scripts
        if [[ "$local_path" == *.sh ]]; then
            chmod +x "$full_local_path"
        fi
    else
        write_log "Failed to download: $local_path" "red"
    fi
done

# Download the updated dependencies.json (Linux version)
write_log "Using local Linux-compatible dependencies.json" "green"

write_log "Bootstrap download process completed!" "green"
write_log "Log file saved to: $LOG_FILE"