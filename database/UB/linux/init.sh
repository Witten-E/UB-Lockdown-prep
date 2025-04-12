#!/bin/bash

script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# ===== Detect Distro =====
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro="${ID,,}"
else
    distro="unknown"
fi

# ===== Only run as root =====
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

OPTS=$(getopt -o "l" --long "headless" -n "$0" -- "$@")

eval set -- "$OPTS"

headless=false

while true; do
    case "$1" in
        -l|--headless)
            headless=true
            shift
        ;;
        --)
            shift
            break
        ;;
        *)
        ;;
    esac
done

if [ "$headless" = true ]; then
    "$script_dir/first_five.sh" -l
else
    if ! "$script_dir/first_five.sh"; then
        exit 10
    fi
fi

case $distro in
    ubuntu|debian)
        sudo apt install -y --reinstall git curl
    ;;
    rhel|centos|fedora)
        sudo dnf reinstall -y git curl
    ;;
    arch|manjaro)
        sudo pacman -S --no-confirm git curl
    ;;
esac


echo "Cloning hungrctl into $(realpath "$script_dir/..") and initializing the tool"
cd "$script_dir/.." || exit 1
if git clone --depth=1 https://github.com/MeHungr/hungrctl 2>/dev/null; then
    echo "[V] Cloned hungrctl successfully"
    cd "$script_dir/../hungrctl" || exit 1
    ./init_hungrctl.sh
else
    echo "[X] Failed to clone hungrctl (may already exist?)"
fi