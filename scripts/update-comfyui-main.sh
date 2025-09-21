#!/bin/bash

# SYNOPSIS
#     ComfyUI Update Script (Linux version)
# DESCRIPTION
#     Updates ComfyUI, custom nodes, and workflows

# Parameters
INSTALL_PATH="${1:-$(dirname "$(dirname "$(realpath "$0")")")}"
COMFY_PATH="$INSTALL_PATH/ComfyUI"
SCRIPT_PATH="$INSTALL_PATH/scripts"
VENV_PYTHON="$COMFY_PATH/venv/bin/python"
LOG_PATH="$INSTALL_PATH/logs"
LOG_FILE="$LOG_PATH/update_log.txt"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_PATH"

# Logging function
write_log() {
    local message="$1"
    local color="${2:-white}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local formatted_message="[$timestamp] [ComfyUI-Updater] $message"
    
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
        write_log "Command failed with exit code $exit_code: $command $args" "red"
        return $exit_code
    fi
}

# Function to update git repository
update_git_repo() {
    local repo_path="$1"
    local repo_name="$2"
    
    if [ ! -d "$repo_path" ]; then
        write_log "Repository not found: $repo_path" "yellow"
        return 1
    fi
    
    write_log "Updating $repo_name..." "cyan"
    
    cd "$repo_path"
    
    # Save current state
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local has_changes=$(git status --porcelain)
    
    if [ -n "$has_changes" ]; then
        write_log "Stashing local changes in $repo_name" "yellow"
        invoke_and_log git stash
    fi
    
    # Update repository
    invoke_and_log git fetch --all
    invoke_and_log git pull origin "$current_branch"
    
    # Restore stashed changes if any
    if [ -n "$has_changes" ]; then
        write_log "Restoring local changes in $repo_name" "yellow"
        git stash pop 2>/dev/null || true
    fi
    
    write_log "$repo_name updated successfully" "green"
    cd - >/dev/null
}

#===========================================================================
# MAIN UPDATE PROCESS
#===========================================================================

write_log "Starting ComfyUI update process..." "green"

echo
echo "==================================================================="
echo "                    ComfyUI Update Process"
echo "==================================================================="
echo

# Check if ComfyUI is installed
if [ ! -d "$COMFY_PATH" ]; then
    write_log "ComfyUI installation not found at: $COMFY_PATH" "red"
    write_log "Please run the installer first." "red"
    exit 1
fi

# Check if virtual environment exists
if [ ! -f "$VENV_PYTHON" ]; then
    write_log "Python virtual environment not found" "red"
    write_log "Please run the installer to create the virtual environment." "red"
    exit 1
fi

# Update ComfyUI core
write_log "=== Updating ComfyUI Core ===" "yellow"
update_git_repo "$COMFY_PATH" "ComfyUI"

# Update custom nodes
write_log "=== Updating Custom Nodes ===" "yellow"
CUSTOM_NODES_PATH="$COMFY_PATH/custom_nodes"

if [ -d "$CUSTOM_NODES_PATH" ]; then
    # Find all git repositories in custom_nodes directory
    find "$CUSTOM_NODES_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r node_dir; do
        if [ -d "$node_dir/.git" ]; then
            node_name=$(basename "$node_dir")
            update_git_repo "$node_dir" "Custom Node: $node_name"
            
            # Check if there's a requirements file and update dependencies
            if [ -f "$node_dir/requirements.txt" ]; then
                write_log "Updating requirements for $node_name" "cyan"
                invoke_and_log "$VENV_PYTHON" -m pip install -r "$node_dir/requirements.txt"
            fi
        fi
    done
else
    write_log "Custom nodes directory not found: $CUSTOM_NODES_PATH" "yellow"
fi

# Update workflows if they exist
WORKFLOWS_PATH="$INSTALL_PATH/workflows"
if [ -d "$WORKFLOWS_PATH" ]; then
    write_log "=== Updating Workflows ===" "yellow"
    update_git_repo "$WORKFLOWS_PATH" "Workflows"
else
    write_log "Workflows directory not found, skipping..." "gray"
fi

# Update Python packages
write_log "=== Updating Python Packages ===" "yellow"
write_log "Upgrading pip and essential packages..." "cyan"
invoke_and_log "$VENV_PYTHON" -m pip install --upgrade pip wheel setuptools

# Update ComfyUI requirements if they exist
if [ -f "$COMFY_PATH/requirements.txt" ]; then
    write_log "Updating ComfyUI requirements..." "cyan"
    invoke_and_log "$VENV_PYTHON" -m pip install -r "$COMFY_PATH/requirements.txt" --upgrade
fi

# Clean up pip cache
write_log "Cleaning pip cache..." "cyan"
invoke_and_log "$VENV_PYTHON" -m pip cache purge

# Final summary
write_log "=== Update Summary ===" "yellow"
write_log "ComfyUI update process completed successfully!" "green"
write_log "Log file saved to: $LOG_FILE" "gray"

echo
echo "==================================================================="
echo "                     Update Complete!"
echo "==================================================================="
echo
echo "All components have been updated:"
echo "  • ComfyUI core"
echo "  • Custom nodes"
echo "  • Python dependencies"
echo "  • Workflows (if present)"
echo
echo "You can now restart ComfyUI to use the latest updates."
echo