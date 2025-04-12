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

cd "$script_dir/../../hungrctl" || exit 2

if ! ./init_hungrctl.sh; then
    echo "[!] hungrctl init failed"
    exit 3
fi