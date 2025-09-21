#!/bin/bash

# SYNOPSIS
#     A bash script to interactively download FLUX models for ComfyUI (Linux version)
# DESCRIPTION
#     This script provides user guidance based on GPU VRAM and downloads FLUX models

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================

# Parameters
INSTALL_PATH="${1:-$(dirname "$(dirname "$(realpath "$0")")")}"
LOG_PATH="$INSTALL_PATH/logs"
LOG_FILE="$LOG_PATH/download_log.txt"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_PATH"

# Logging function
write_log() {
    local message="$1"
    local color="${2:-white}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local formatted_message="[$timestamp] [ModelDownloader-FLUX] $message"
    
    # Print to console with color
    case $color in
        red) echo -e "\e[31m$message\e[0m" ;;
        green) echo -e "\e[32m$message\e[0m" ;;
        yellow) echo -e "\e[33m$message\e[0m" ;;
        gray) echo -e "\e[90m$message\e[0m" ;;
        cyan) echo -e "\e[36m$message\e[0m" ;;
        *) echo "$message" ;;
    esac
    
    # Append to log file
    echo "$formatted_message" >> "$LOG_FILE"
}

# Function to execute commands and log them
invoke_and_log() {
    local command="$1"
    shift
    local args="$*"
    
    write_log "Executing: $command $args"
    
    if "$command" $args >> "$LOG_FILE" 2>&1; then
        return 0
    else
        local exit_code=$?
        write_log "FATAL ERROR trying to execute command: $command $args" "red"
        return $exit_code
    fi
}

# Function to download files
download_file() {
    local uri="$1"
    local out_file="$2"
    
    if [ -f "$out_file" ]; then
        write_log "Skipping: $(basename "$out_file") (already exists)." "gray"
        return 0
    fi
    
    # Present as a modern browser to avoid being blocked
    local modern_user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    local file_name=$(basename "$uri")
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$out_file")"
    
    if command -v aria2c >/dev/null 2>&1; then
        write_log "Downloading: $file_name"
        local aria_args="--disable-ipv6 -c -x 16 -s 16 -k 1M --user-agent=\"$modern_user_agent\" --dir=\"$(dirname "$out_file")\" --out=\"$(basename "$out_file")\" \"$uri\""
        invoke_and_log aria2c $aria_args
    elif command -v curl >/dev/null 2>&1; then
        write_log "Aria2 not found. Using curl: $file_name" "yellow"
        curl -L -A "$modern_user_agent" "$uri" -o "$out_file"
    elif command -v wget >/dev/null 2>&1; then
        write_log "Aria2 and curl not found. Using wget: $file_name" "yellow"
        wget --user-agent="$modern_user_agent" "$uri" -O "$out_file"
    else
        write_log "ERROR: No download tool available" "red"
        return 1
    fi
}

# Function to ask user questions
ask_question() {
    local prompt="$1"
    shift
    local choices=("$@")
    local valid_answers=()
    
    # Extract valid answers from choices (letters before the closing parenthesis)
    for choice in "${choices[@]}"; do
        if [[ $choice =~ ^([A-Za-z]) ]]; then
            valid_answers+=(${BASH_REMATCH[1]})
        fi
    done
    
    while true; do
        echo
        echo "$prompt"
        for choice in "${choices[@]}"; do
            echo "  $choice"
        done
        echo
        read -p "Your choice: " user_choice
        
        # Convert to uppercase for comparison
        user_choice=$(echo "$user_choice" | tr '[:lower:]' '[:upper:]')
        
        for valid in "${valid_answers[@]}"; do
            if [ "$user_choice" = "$(echo "$valid" | tr '[:lower:]' '[:upper:]')" ]; then
                echo "$user_choice"
                return 0
            fi
        done
        
        echo "Invalid choice. Please try again."
    done
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================

write_log "Starting FLUX model downloader..." "green"

# Define paths
MODELS_PATH="$INSTALL_PATH/ComfyUI/models"
CHECKPOINTS_DIR="$MODELS_PATH/checkpoints"
UNET_DIR="$MODELS_PATH/unet"
VAE_DIR="$MODELS_PATH/vae"
CLIP_DIR="$MODELS_PATH/clip"

# Create model directories
mkdir -p "$CHECKPOINTS_DIR/FLUX" "$UNET_DIR" "$VAE_DIR" "$CLIP_DIR"

write_log "Model directories created/verified" "green"

# User guidance based on VRAM
echo
echo "==================================================================="
echo "                    FLUX Model Download Wizard"
echo "==================================================================="
echo
echo "Before proceeding, please consider your GPU's VRAM:"
echo
echo "• 24GB+ VRAM: You can run all FLUX models comfortably"
echo "• 16GB VRAM: Recommended for FLUX Dev and Schnell models"
echo "• 12GB VRAM: FLUX Schnell only, may need optimizations"
echo "• 8GB VRAM: Not recommended without significant optimizations"
echo

# Ask user questions
dev_choice=$(ask_question "Do you want to download FLUX Dev models?" \
    "A) Full Precision (12GB)" \
    "B) FP8 Precision (7GB)" \
    "C) Both" \
    "D) No")

schnell_choice=$(ask_question "Do you want to download FLUX Schnell models?" \
    "A) Full Precision (12GB)" \
    "B) FP8 Precision (7GB)" \
    "C) Both" \
    "D) No")

shared_choice=$(ask_question "Do you want to download shared FLUX models (VAE, CLIP)?" \
    "A) Yes" \
    "B) No")

# Download files based on user choices
write_log "Starting FLUX model downloads..." "cyan"
base_url="https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"

# FLUX Dev models
case $dev_choice in
    A)
        write_log "Downloading FLUX Dev (Full Precision)..."
        download_file "$base_url/checkpoints/FLUX/flux1-dev.safetensors" "$CHECKPOINTS_DIR/FLUX/flux1-dev.safetensors"
        ;;
    B)
        write_log "Downloading FLUX Dev (FP8)..."
        download_file "$base_url/unet/flux1-dev-fp8.safetensors" "$UNET_DIR/flux1-dev-fp8.safetensors"
        ;;
    C)
        write_log "Downloading FLUX Dev (Both versions)..."
        download_file "$base_url/checkpoints/FLUX/flux1-dev.safetensors" "$CHECKPOINTS_DIR/FLUX/flux1-dev.safetensors"
        download_file "$base_url/unet/flux1-dev-fp8.safetensors" "$UNET_DIR/flux1-dev-fp8.safetensors"
        ;;
    D)
        write_log "Skipping FLUX Dev models." "gray"
        ;;
esac

# FLUX Schnell models
case $schnell_choice in
    A)
        write_log "Downloading FLUX Schnell (Full Precision)..."
        download_file "$base_url/checkpoints/FLUX/flux1-schnell.safetensors" "$CHECKPOINTS_DIR/FLUX/flux1-schnell.safetensors"
        ;;
    B)
        write_log "Downloading FLUX Schnell (FP8)..."
        download_file "$base_url/unet/flux1-schnell-fp8.safetensors" "$UNET_DIR/flux1-schnell-fp8.safetensors"
        ;;
    C)
        write_log "Downloading FLUX Schnell (Both versions)..."
        download_file "$base_url/checkpoints/FLUX/flux1-schnell.safetensors" "$CHECKPOINTS_DIR/FLUX/flux1-schnell.safetensors"
        download_file "$base_url/unet/flux1-schnell-fp8.safetensors" "$UNET_DIR/flux1-schnell-fp8.safetensors"
        ;;
    D)
        write_log "Skipping FLUX Schnell models." "gray"
        ;;
esac

# Shared models (VAE, CLIP)
case $shared_choice in
    A)
        write_log "Downloading shared FLUX models..."
        download_file "$base_url/vae/ae.safetensors" "$VAE_DIR/ae.safetensors"
        download_file "$base_url/clip/clip_l.safetensors" "$CLIP_DIR/clip_l.safetensors"
        download_file "$base_url/clip/t5xxl_fp8_e4m3fn.safetensors" "$CLIP_DIR/t5xxl_fp8_e4m3fn.safetensors"
        download_file "$base_url/clip/t5xxl_fp16.safetensors" "$CLIP_DIR/t5xxl_fp16.safetensors"
        
        # Download ControlNet models
        CONTROLNET_DIR="$MODELS_PATH/controlnet"
        mkdir -p "$CONTROLNET_DIR"
        download_file "$base_url/controlnet/flux-canny-controlnet-v3.safetensors" "$CONTROLNET_DIR/flux-canny-controlnet-v3.safetensors"
        download_file "$base_url/controlnet/flux-depth-controlnet-v3.safetensors" "$CONTROLNET_DIR/flux-depth-controlnet-v3.safetensors"
        ;;
    B)
        write_log "Skipping shared FLUX models." "gray"
        ;;
esac

write_log "FLUX model download completed!" "green"
echo
echo "==================================================================="
echo "                     Download Complete!"
echo "==================================================================="
echo
echo "Models have been downloaded to: $MODELS_PATH"
echo "You can now use FLUX models in ComfyUI."
echo