#!/bin/bash

# SYNOPSIS
#     A dedicated installer for ComfyUI custom nodes only.
# DESCRIPTION
#     This script installs custom nodes for an existing ComfyUI installation.
#     It expects ComfyUI to already be installed with a virtual environment.

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# Get ComfyUI root path from first argument (mandatory)
if [ $# -eq 0 ]; then
    echo "Error: ComfyUI root directory is required as an argument."
    exit 1
fi

COMFY_PATH="$1"
# Derive other paths from ComfyUI root and script location
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
INSTALL_PATH="$(dirname "$SCRIPT_DIR")"
SCRIPT_PATH="$INSTALL_PATH/scripts"
VENV_PYTHON="$COMFY_PATH/venv/bin/python"
LOG_PATH="$INSTALL_PATH/logs"
LOG_FILE="$LOG_PATH/install_custom_nodes_log.txt"

# Load dependencies configuration
DEPENDENCIES_FILE="$(dirname "$0")/dependencies.json"
if [ ! -f "$DEPENDENCIES_FILE" ]; then
    echo "FATAL: dependencies.json not found..." >&2
    read -p "Press Enter to continue..."
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOG_PATH"

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
            local wrapped_message="| $message |"
            local separator=$(printf '=%.0s' $(seq 1 ${#wrapped_message}))
            local console_message="\n$separator\n$wrapped_message\n$separator"
            local log_message="[$timestamp] $message"
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
        cyan) echo -e "\e[36m$console_message\e[0m" ;;
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

#===========================================================================
# SECTION 2: VALIDATION
#===========================================================================

write_log "ComfyUI Custom Nodes Installer" 0

# Check if ComfyUI is installed
if [ ! -d "$COMFY_PATH" ]; then
    write_log "ComfyUI installation not found at: $COMFY_PATH" 1 "red"
    write_log "Please install ComfyUI first using the main installer." 1 "red"
    read -p "Press Enter to exit..."
    exit 1
fi

# Check if virtual environment exists
if [ ! -f "$VENV_PYTHON" ]; then
    write_log "Python virtual environment not found at: $VENV_PYTHON" 1 "red"
    write_log "Please ensure ComfyUI is properly installed with its virtual environment." 1 "red"
    read -p "Press Enter to exit..."
    exit 1
fi

# Test the virtual environment
if ! "$VENV_PYTHON" --version > /dev/null 2>&1; then
    write_log "Python virtual environment is not functional" 1 "red"
    write_log "Please reinstall ComfyUI to fix the virtual environment." 1 "red"
    read -p "Press Enter to exit..."
    exit 1
fi

write_log "ComfyUI installation found and virtual environment is functional" 1 "green"

#===========================================================================
# SECTION 3: INSTALL CUSTOM NODES
#===========================================================================

write_log "Installing Custom Nodes" 0

CUSTOM_NODES_CSV="$SCRIPT_PATH/custom_nodes.csv"
if [ -f "$CUSTOM_NODES_CSV" ]; then
    CUSTOM_NODES_PATH="$COMFY_PATH/custom_nodes"
    mkdir -p "$CUSTOM_NODES_PATH"
    
    # Count total nodes for progress tracking
    TOTAL_NODES=$(tail -n +2 "$CUSTOM_NODES_CSV" | wc -l)
    CURRENT_NODE=0
    
    write_log "Found $TOTAL_NODES custom nodes to process" 1
    
    # Skip header line and process each custom node
    tail -n +2 "$CUSTOM_NODES_CSV" | while IFS=',' read -r name repo_url subfolder requirements_file; do
        if [ -n "$name" ] && [ -n "$repo_url" ]; then
            ((CURRENT_NODE++))
            write_log "[$CURRENT_NODE/$TOTAL_NODES] Processing custom node: $name" 1
            
            if [ -n "$subfolder" ]; then
                NODE_PATH="$CUSTOM_NODES_PATH/$subfolder"
            else
                NODE_PATH="$CUSTOM_NODES_PATH/$name"
            fi
            
            if [ ! -d "$NODE_PATH" ]; then
                write_log "Cloning repository: $repo_url" 2
                if invoke_and_log git clone "$repo_url" "$NODE_PATH"; then
                    write_log "Successfully cloned $name" 2 "green"
                    
                    # Install requirements if specified
                    if [ -n "$requirements_file" ] && [ -f "$NODE_PATH/$requirements_file" ]; then
                        write_log "Installing requirements: $requirements_file" 2
                        if invoke_and_log "$VENV_PYTHON" -m pip install -r "$NODE_PATH/$requirements_file"; then
                            write_log "Successfully installed requirements for $name" 2 "green"
                        else
                            write_log "Failed to install requirements for $name" 2 "yellow"
                        fi
                    fi
                else
                    write_log "Failed to clone $name" 2 "red"
                fi
            else
                write_log "Custom node $name already exists, skipping" 2 "gray"
            fi
        else
            write_log "Skipping invalid entry: name='$name', repo_url='$repo_url'" 2 "yellow"
        fi
    done
else
    write_log "Custom nodes CSV file not found: $CUSTOM_NODES_CSV" 1 "yellow"
    write_log "Please ensure the custom_nodes.csv file exists in the scripts directory." 1 "yellow"
    read -p "Press Enter to exit..."
    exit 1
fi

#===========================================================================
# SECTION 4: COMPLETION
#===========================================================================

write_log "Custom Nodes Installation Complete!" 0 "green"
write_log "All custom nodes have been installed to: $CUSTOM_NODES_PATH" 1 "green"
write_log "You can now start ComfyUI to use the newly installed custom nodes." 1 "green"

echo
echo "============================================================"
echo "                 Installation Summary"
echo "============================================================"
echo "• Custom nodes installed to: $CUSTOM_NODES_PATH"
echo "• Log file saved to: $LOG_FILE"
echo "• You can now start ComfyUI to use the new nodes"
echo "============================================================"
echo

read -p "Press Enter to close this window."