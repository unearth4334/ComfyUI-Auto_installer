#!/bin/bash

# SYNOPSIS
#     An automated installer for ComfyUI and its dependencies on Linux.
# DESCRIPTION
#     This script streamlines the setup of ComfyUI, including Python, Git,
#     all required Python packages, custom nodes, and optional models.

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# Set default install path to parent directory of scripts folder
INSTALL_PATH="${1:-$(dirname "$(dirname "$(realpath "$0")")")}"
COMFY_PATH="$INSTALL_PATH/ComfyUI"
SCRIPT_PATH="$INSTALL_PATH/scripts"
VENV_PYTHON="$COMFY_PATH/venv/bin/python"
LOG_PATH="$INSTALL_PATH/logs"
LOG_FILE="$LOG_PATH/install_log.txt"

# Load dependencies configuration
DEPENDENCIES_FILE="$(dirname "$0")/dependencies.json"
if [ ! -f "$DEPENDENCIES_FILE" ]; then
    echo "FATAL: dependencies.json not found..." >&2
    read -p "Press Enter to continue..."
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOG_PATH"

# Global step tracking
TOTAL_STEPS=11
CURRENT_STEP=0

# Function to write log messages
write_log() {
    local message="$1"
    local level="${2:-1}"
    local color="${3:-white}"
    
    local prefix=""
    local default_color="white"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        -2) prefix="" ;;
        0)
            ((CURRENT_STEP++))
            local wrapped_message="| [Step $CURRENT_STEP/$TOTAL_STEPS] $message |"
            local separator=$(printf '=%.0s' $(seq 1 ${#wrapped_message}))
            local console_message="\n$separator\n$wrapped_message\n$separator"
            local log_message="[$timestamp] [Step $CURRENT_STEP/$TOTAL_STEPS] $message"
            default_color="yellow"
            ;;
        1) prefix="  - " ;;
        2) prefix="    -> " ;;
        3) prefix="      [INFO] " ;;
    esac
    
    if [ "$color" = "default" ]; then color="$default_color"; fi
    
    if [ $level -ne 0 ]; then
        log_message="[$timestamp] $(echo "$prefix" | xargs) $message"
        console_message="$prefix$message"
    fi
    
    # Print to console with color (simplified color support)
    case $color in
        red) echo -e "\e[31m$console_message\e[0m" ;;
        green) echo -e "\e[32m$console_message\e[0m" ;;
        yellow) echo -e "\e[33m$console_message\e[0m" ;;
        gray) echo -e "\e[90m$console_message\e[0m" ;;
        *) echo "$console_message" ;;
    esac
    
    # Append to log file
    echo "$log_message" >> "$LOG_FILE"
}

# Function to execute commands and log them
invoke_and_log() {
    local command="$1"
    shift
    local args="$*"
    
    local temp_log_file=$(mktemp)
    
    write_log "Executing: $command $args" 3
    
    if "$command" $args >> "$temp_log_file" 2>&1; then
        cat "$temp_log_file" >> "$LOG_FILE"
        rm -f "$temp_log_file"
        return 0
    else
        local exit_code=$?
        write_log "COMMAND FAILED with exit code $exit_code: $command $args" 3 "red"
        cat "$temp_log_file" >> "$LOG_FILE"
        rm -f "$temp_log_file"
        return $exit_code
    fi
}

# Function to download files
download_file() {
    local uri="$1"
    local out_file="$2"
    
    if [ -f "$out_file" ]; then
        write_log "Skipping: $(basename "$out_file") (already exists)." 3 "gray"
        return 0
    fi
    
    local file_name=$(basename "$uri")
    local modern_user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    
    if command -v aria2c >/dev/null 2>&1; then
        write_log "Downloading: $file_name" 3
        local aria_args="--disable-ipv6 -c -x 16 -s 16 -k 1M --user-agent=\"$modern_user_agent\" --dir=\"$(dirname "$out_file")\" --out=\"$(basename "$out_file")\" \"$uri\""
        invoke_and_log aria2c $aria_args
    elif command -v curl >/dev/null 2>&1; then
        write_log "Aria2 not found. Using curl: $file_name" 3 "yellow"
        curl -L -A "$modern_user_agent" "$uri" -o "$out_file"
    elif command -v wget >/dev/null 2>&1; then
        write_log "Aria2 and curl not found. Using wget: $file_name" 3 "yellow"
        wget --user-agent="$modern_user_agent" "$uri" -O "$out_file"
    else
        write_log "ERROR: No download tool available (aria2c, curl, or wget)" 3 "red"
        return 1
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to install packages based on distribution
install_packages() {
    local packages=("$@")
    local distro=$(detect_distro)
    
    case $distro in
        ubuntu|debian)
            apt-get update
            apt-get install -y "${packages[@]}"
            ;;
        fedora|centos|rhel)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y "${packages[@]}"
            else
                yum install -y "${packages[@]}"
            fi
            ;;
        arch|manjaro)
            pacman -Syu --noconfirm "${packages[@]}"
            ;;
        opensuse*)
            zypper install -y "${packages[@]}"
            ;;
        *)
            write_log "Unsupported distribution: $distro" 1 "red"
            write_log "Please install the following packages manually: ${packages[*]}" 1 "yellow"
            return 1
            ;;
    esac
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================

write_log ">>> CONFIRMATION: RUNNING FINAL SCRIPT <<<" -2 "green"

clear
# ASCII Banner
cat << 'EOL'
===============================================================================
                      __  __               ___    _ ____  ______
                     / / / /___ ___  ___  /   |  (_) __ \/_  __/
                    / / / / __ `__ \/ _ \/ /| | / / /_/ / / /   
                   / /_/ / / / / / /  __/ ___ |/ / _, _/ / /    
                   \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/     
                                                               
                       ComfyUI Auto-Installer (Linux)
===============================================================================
EOL

write_log "Starting ComfyUI installation process..." 0

# --- Step 1: System Requirements Check ---
write_log "Checking System Requirements" 0

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    write_log "ERROR: This script must be run as root or with sudo" 1 "red"
    exit 1
fi

write_log "Root privileges confirmed" 1 "green"

# Detect system architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    write_log "WARNING: Detected architecture $ARCH. This installer is optimized for x86_64" 1 "yellow"
fi

write_log "System architecture: $ARCH" 1

# --- Step 2: Python Installation Check ---
write_log "Checking Python Installation" 0

REQUIRED_PYTHON_VERSION="3.12"
PYTHON_COMMAND=""

# Check for python3.12 specifically
if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_COMMAND="python3.12"
    CURRENT_VERSION=$(python3.12 --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
    write_log "Python 3.12 found: $CURRENT_VERSION" 1 "green"
elif command -v python3 >/dev/null 2>&1; then
    CURRENT_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+')
    if [[ "$CURRENT_VERSION" == "3.12" ]]; then
        PYTHON_COMMAND="python3"
        write_log "Python 3.12 found via python3 command" 1 "green"
    else
        write_log "Python 3 found but version is $CURRENT_VERSION, need 3.12" 1 "yellow"
    fi
fi

# Install Python 3.12 if not found
if [ -z "$PYTHON_COMMAND" ]; then
    write_log "Installing Python 3.12..." 1 "yellow"
    
    case $(detect_distro) in
        ubuntu|debian)
            install_packages software-properties-common
            add-apt-repository -y ppa:deadsnakes/ppa
            apt-get update
            install_packages python3.12 python3.12-venv python3.12-pip python3.12-dev
            ;;
        fedora)
            install_packages python3.12 python3.12-pip python3.12-devel
            ;;
        *)
            write_log "Please install Python 3.12 manually for your distribution" 1 "red"
            exit 1
            ;;
    esac
    
    PYTHON_COMMAND="python3.12"
    write_log "Python 3.12 installed successfully" 1 "green"
fi

# --- Step 3: Required Tools Check ---
write_log "Checking for Required Tools" 0

# Essential packages for most distributions
ESSENTIAL_PACKAGES=("git" "build-essential" "cmake" "pkg-config" "aria2" "ninja-build" "ccache" "p7zip-full" "unzip" "curl" "wget")

# Adjust package names based on distribution
case $(detect_distro) in
    fedora|centos|rhel)
        ESSENTIAL_PACKAGES=("git" "gcc" "gcc-c++" "make" "cmake" "pkg-config" "aria2" "ninja-build" "ccache" "p7zip" "unzip" "curl" "wget")
        ;;
    arch|manjaro)
        ESSENTIAL_PACKAGES=("git" "base-devel" "cmake" "pkg-config" "aria2" "ninja" "ccache" "p7zip" "unzip" "curl" "wget")
        ;;
esac

write_log "Installing essential tools..." 1
install_packages "${ESSENTIAL_PACKAGES[@]}"
write_log "Essential tools installed" 1 "green"

# --- Step 4: ComfyUI Repository Setup ---
write_log "Setting up ComfyUI Repository" 0

if [ ! -d "$COMFY_PATH" ]; then
    write_log "Cloning ComfyUI repository..." 1
    invoke_and_log git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_PATH"
    write_log "ComfyUI cloned successfully" 2 "green"
else
    write_log "ComfyUI directory already exists" 1 "green"
fi

# Create Python virtual environment
if [ ! -d "$COMFY_PATH/venv" ]; then
    write_log "Creating Python virtual environment..." 1
    invoke_and_log "$PYTHON_COMMAND" -m venv "$COMFY_PATH/venv"
    write_log "Virtual environment created successfully" 2 "green"
else
    write_log "Virtual environment already exists" 1 "green"
fi

# Create the 'user' directory to prevent first-launch database errors
USER_FOLDER_PATH="$COMFY_PATH/user"
if [ ! -d "$USER_FOLDER_PATH" ]; then
    write_log "Creating 'user' directory to prevent database issues" 1
    mkdir -p "$USER_FOLDER_PATH"
fi

invoke_and_log git config --global --add safe.directory "$COMFY_PATH"

# --- Step 5: Install Core Dependencies ---
write_log "Installing Core Dependencies" 0

write_log "Upgrading pip and wheel" 1
invoke_and_log "$VENV_PYTHON" -m pip install --upgrade pip wheel

write_log "Installing PyTorch packages" 1
invoke_and_log "$VENV_PYTHON" -m pip install torch==2.8.0+cu129 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu129

write_log "Installing ComfyUI requirements" 1
if [ -f "$COMFY_PATH/requirements.txt" ]; then
    invoke_and_log "$VENV_PYTHON" -m pip install -r "$COMFY_PATH/requirements.txt"
fi

# Install additional packages
write_log "Installing additional packages" 1
invoke_and_log "$VENV_PYTHON" -m pip install facexlib cython onnxruntime onnxruntime-gpu insightface
invoke_and_log "$VENV_PYTHON" -m pip install numpy==1.26.4 pandas transformers==4.49.0

# --- Step 6: Install Custom Nodes ---
write_log "Installing Custom Nodes" 0

CUSTOM_NODES_CSV="$SCRIPT_PATH/custom_nodes.csv"
if [ -f "$CUSTOM_NODES_CSV" ]; then
    CUSTOM_NODES_PATH="$COMFY_PATH/custom_nodes"
    mkdir -p "$CUSTOM_NODES_PATH"
    
    # Skip header line and process each custom node
    tail -n +2 "$CUSTOM_NODES_CSV" | while IFS=',' read -r name repo_url subfolder requirements_file; do
        if [ -n "$name" ] && [ -n "$repo_url" ]; then
            write_log "Installing custom node: $name" 1
            
            if [ -n "$subfolder" ]; then
                NODE_PATH="$CUSTOM_NODES_PATH/$subfolder"
            else
                NODE_PATH="$CUSTOM_NODES_PATH/$name"
            fi
            
            if [ ! -d "$NODE_PATH" ]; then
                invoke_and_log git clone "$repo_url" "$NODE_PATH"
                
                # Install requirements if specified
                if [ -n "$requirements_file" ] && [ -f "$NODE_PATH/$requirements_file" ]; then
                    write_log "Installing requirements for $name" 2
                    invoke_and_log "$VENV_PYTHON" -m pip install -r "$NODE_PATH/$requirements_file"
                fi
            else
                write_log "Custom node $name already exists" 2 "gray"
            fi
        fi
    done
else
    write_log "Custom nodes CSV file not found: $CUSTOM_NODES_CSV" 1 "yellow"
fi

# --- Step 7: Install Git Repositories ---
write_log "Installing Additional Git Repositories" 0

# Install xformers
write_log "Installing xformers" 1
XFORMERS_PATH="$INSTALL_PATH/xformers_temp"
invoke_and_log git clone https://github.com/facebookresearch/xformers.git "$XFORMERS_PATH"
invoke_and_log "$VENV_PYTHON" -m pip install "$XFORMERS_PATH"
rm -rf "$XFORMERS_PATH"

# Install SageAttention
write_log "Installing SageAttention" 1
SAGE_PATH="$INSTALL_PATH/SageAttention_temp"
invoke_and_log git clone https://github.com/thu-ml/SageAttention "$SAGE_PATH"
invoke_and_log "$VENV_PYTHON" -m pip install --no-build-isolation --verbose "$SAGE_PATH"
rm -rf "$SAGE_PATH"

# --- Step 8: Download Configuration Files ---
write_log "Downloading Configuration Files" 0

# Download comfy settings
COMFY_SETTINGS_DIR="$COMFY_PATH/user/default"
mkdir -p "$COMFY_SETTINGS_DIR"
download_file "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/others/comfy.settings.json" "$COMFY_SETTINGS_DIR/comfy.settings.json"

# --- Step 9: Set Permissions ---
write_log "Setting Directory Permissions" 0

write_log "Setting permissions for installation directory" 1
chmod -R 755 "$INSTALL_PATH"
chown -R $SUDO_USER:$SUDO_USER "$INSTALL_PATH" 2>/dev/null || true

# --- Step 10: Copy Base Models ---
write_log "Copying Base Models" 0

MODELS_SOURCE="$COMFY_PATH/models"
if [ -d "$MODELS_SOURCE" ]; then
    write_log "Base models directory already exists" 1 "green"
else
    write_log "Base models directory will be created when needed" 1
fi

# --- Step 11: Optional Model Pack Downloads ---
write_log "Optional Model Pack Downloads" 0

MODEL_PACKS=(
    "FLUX:download-flux-models.sh"
    "WAN2.1:download-wan2.1-models.sh"
    "WAN2.2:download-wan2.2-models.sh"
    "HIDREAM:download-hidream-models.sh"
    "LTXV:download-ltxv-models.sh"
    "QWEN:download-qwen-models.sh"
)

for pack in "${MODEL_PACKS[@]}"; do
    IFS=':' read -r pack_name script_name <<< "$pack"
    
    echo
    read -p "Do you want to download $pack_name models? (y/N): " choice
    case $choice in
        [Yy]* )
            write_log "User selected to download $pack_name models" 1
            SCRIPT_FILE="$SCRIPT_PATH/$script_name"
            if [ -f "$SCRIPT_FILE" ]; then
                chmod +x "$SCRIPT_FILE"
                bash "$SCRIPT_FILE" "$INSTALL_PATH"
            else
                write_log "Script not found: $script_name" 2 "yellow"
            fi
            ;;
        * )
            write_log "Skipping $pack_name models" 1 "gray"
            ;;
    esac
done

write_log "Installation of ComfyUI and all nodes is complete!" -2 "green"
read -p "Press Enter to close this window."