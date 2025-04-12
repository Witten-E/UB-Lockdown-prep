#!/bin/bash

# Usage: ./exclude_users_password_script.sh <users to exclude from password change separated by spaces>

# Array of users to exclude from lock
excluded_from_lock=("sockpuppet" "puppetmaster" "blackteam")



# Array of users to include in lock function and copies to array for pw function
mapfile -t users_to_lock < <(awk -F: '$7 !~ /(nologin|false)/ {print $1}' /etc/passwd)
pw_users=("${users_to_lock[@]}")

# ===== Parse flags =====
OPTS=$(getopt -o "hlp:" --long "help,headless,password:" -n "$0" -- "$@")

eval set -- "$OPTS"

headless=false

while true; do
    case "$1" in
        -h|--help)
            echo "Usage: $0 [-l|--headless] [-p|--password <password>] [users to exclude from password change]"
            exit 0
        ;;
        -l|--headless)
            headless=true
            shift
        ;;
        -p|--password)
            input_password="$2"
            shift 2
        ;;
        --)
            shift
            break
        ;;
        *)
        ;;
    esac
done

# Array of users to exclude from pw change provided by command args
excluded_pw_users=("$@")

# Helper function to check if a user is in the exclusion list
is_excluded() {
    local user="$1"
    shift
    local list=("$@")
    for excluded in "${list[@]}"; do
        if [[ "$user" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

# Locks all users in users_to_lock
lock_users() {
    for user in "${users_to_lock[@]}"; do
        if passwd -l "$user" >/dev/null 2>&1; then
            echo "Account locked for: $user"
        else
            echo "Failed to lock user: $user"
        fi
    done
}

# Changes passwords for users in pw_users
change_passwords() {
    for user in "${pw_users[@]}"; do
        echo "$user:$1" | chpasswd
        if [ $? -eq 0 ]; then
            echo "Password changed for user: $user"
        else
            echo "Failed to change password for user: $user"
        fi
    done
}

# Filter out users to exclude from locking
exclude_from_lock() {
    local temp_users=()
    for user in "${users_to_lock[@]}"; do
        if is_excluded "$user" "${excluded_from_lock[@]}"; then
            echo "Removing user from lock list: $user"
        else
            temp_users+=("$user")
        fi
    done
    users_to_lock=("${temp_users[@]}")
}

# Filter out users to exclude from password change
exclude_from_pw_change() {
    local temp_users=()
    for user in "${pw_users[@]}"; do
        if is_excluded "$user" "${excluded_pw_users[@]}"; then
            echo "Removing user from password change list: $user"
        else
            temp_users+=("$user")
        fi
    done
    pw_users=("${temp_users[@]}")
}

# Confirm the changes before applying
confirm_changes() {
    echo "The following users will have their passwords changed:"
    for user in "${pw_users[@]}"; do
        echo "- $user"
    done
    echo
    echo "The following users will be locked:"
    for user in "${users_to_lock[@]}"; do
        echo "- $user"
    done
    
    read -r -p "Do you want to proceed? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Changes cancelled. Exiting..."
        exit 10
    fi
}

# Main

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

if [ "$headless" = true ]; then
    if [ -z "$input_password" ]; then
        echo "Headless mode requires a password passed with -p or --password"
        exit 1
    fi
    password="$input_password"
else
    read -rsp "Enter the new password: " password
    echo
    read -rsp "Confirm the new password: " password_confirm
    echo
    
    if [ "$password" != "$password_confirm" ]; then
        echo "Passwords do not match! Exiting..."
        exit 1
    fi
fi

exclude_from_pw_change
exclude_from_lock

if [ "$headless" = false ]; then
    confirm_changes
fi

change_passwords "$password"
lock_users