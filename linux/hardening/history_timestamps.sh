#!/bin/bash

# ============================================================================
# Script Name: history_timestamps.sh
# Description: Adds or removes timestamp and persistence settings for the
#              `history` command across all users on the system.
#
# Usage:
#   sudo ./history_config.sh           # Apply timestamping and persistence
#   sudo ./history_config.sh --revert  # Remove timestamping and persistence
#   sudo ./history_config.sh -h|--help # Show usage
#
# Requirements:
#   Must be run as root.
# ============================================================================

# Show usage help
show_help() {
    echo "Usage: sudo $0 [OPTION]"
    echo
    echo "Options:"
    echo "  --revert        Remove timestamping and persistence from all users"
    echo "  -h, --help      Show this help message and exit"
    exit 0
}

# Handle help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Check for root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Config lines to add/remove
timestamp_line="export HISTTIMEFORMAT='%d/%m/%y %T '"
history_persist_line="export PROMPT_COMMAND='history -a'"

# Detect mode
revert=false
if [[ "$1" == "--revert" ]]; then
    revert=true
    echo "Reverting history timestamp and persistence settings..."
else
    echo "Applying history timestamp and persistence settings..."
fi

modify_bashrc() {
    local bashrc="$1"

    # Backup .bashrc
    cp "$bashrc" "${bashrc}.bak"

    if $revert; then
        # Remove lines
        sed -i "/HISTTIMEFORMAT/d" "$bashrc"
        sed -i "/PROMPT_COMMAND=.*history -a/d" "$bashrc"
        echo "Removed history config from $bashrc"
    else
        # Add lines if not present
        if ! grep -q "HISTTIMEFORMAT" "$bashrc"; then
            echo "Adding HISTTIMEFORMAT to $bashrc"
            echo "$timestamp_line" >> "$bashrc"
        fi
        if ! grep -q "PROMPT_COMMAND=.*history -a" "$bashrc"; then
            echo "Adding PROMPT_COMMAND to $bashrc"
            echo "$history_persist_line" >> "$bashrc"
        fi
    fi
}

# Current user
current_user_home=$(eval echo "~$SUDO_USER")
current_user_bashrc="$current_user_home/.bashrc"
if [[ -f "$current_user_bashrc" ]]; then
    modify_bashrc "$current_user_bashrc"
    sudo -u "$SUDO_USER" bash -c "source $current_user_bashrc"
fi

# /etc/skel
if [[ -f "/etc/skel/.bashrc" ]]; then
    modify_bashrc "/etc/skel/.bashrc"
fi

# Existing users
for user_dir in /home/*; do
    user_bashrc="$user_dir/.bashrc"
    if [[ -f "$user_bashrc" ]]; then
        modify_bashrc "$user_bashrc"
    fi
done

if $revert; then
    echo "History timestamp and persistence settings have been removed."
else
    echo "History timestamp and persistence settings have been applied."
fi

