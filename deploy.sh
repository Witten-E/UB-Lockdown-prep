#!/bin/bash

# === Config ===
playbook="deploy.yml"
inventory="hosts"
LIMIT="$1"   # Optional: target subset, like "ubuntu_ftp"

# ===== Detect Distro =====
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro="${ID,,}"
else
    distro="unknown"
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "[*] Ansible not found. Attempting to install..."
    case "$distro" in
        ubuntu|debian)
            apt-get update -y &>/dev/null
            if apt-get install -y python3 python3-pip ansible sshpass &>/dev/null; then
                echo "[V] Installed Ansible via apt"
            else
                echo "[!] apt install failed — trying pip fallback"
                pip3 install --user ansible || {
                    echo "[X] pip fallback failed"
                    exit 1
                }
                export PATH="$HOME/.local/bin:$PATH"
            fi
        ;;
        rhel|centos|fedora)
            if command -v dnf &>/dev/null; then
                dnf update -y &>/dev/null
                dnf install -y python3 python3-pip ansible sshpass &>/dev/null || {
                    echo "[!] dnf install failed — trying pip fallback"
                    pip3 install --user ansible || {
                        echo "[X] pip fallback failed"
                        exit 1
                    }
                    export PATH="$HOME/.local/bin:$PATH"
                }
            else
                yum update -y &>/dev/null
                yum install -y python3 python3-pip ansible sshpass &>/dev/null || {
                    echo "[!] yum install failed — trying pip fallback"
                    pip3 install --user ansible || {
                        echo "[X] pip fallback failed"
                        exit 1
                    }
                    export PATH="$HOME/.local/bin:$PATH"
                }
            fi
        ;;
        arch|manjaro)
            pacman -Syu --noconfirm &>/dev/null
            if ! pacman -S --noconfirm ansible python-pip sshpass &>/dev/null; then
                echo "[!] pacman install failed — trying pip fallback"
                pip3 install --user ansible || {
                    echo "[X] pip fallback failed"
                    exit 1
                }
                export PATH="$HOME/.local/bin:$PATH"
            else
                echo "[V] Installed Ansible via pacman"
            fi
        ;;
        *)
            echo "[X] Unsupported distro: $distro"
            echo "[!] Trying pip fallback..."
            pip3 install --user ansible || {
                echo "[X] pip fallback failed"
                exit 1
            }
            export PATH="$HOME/.local/bin:$PATH"
        ;;
    esac
fi

cp "$inventory" "$inventory.bak"
trap 'mv "$inventory.bak" "$inventory"; echo "[*] Cleaned up inventory"; exit' INT TERM



# === Sanity checks ===
if [ ! -f "$playbook" ]; then
    echo "[!] Playbook not found: $playbook"
    exit 1
fi

if [ ! -f "$inventory" ]; then
    echo "[!] Inventory file not found: $inventory"
    exit 1
fi

# === Run the playbook ===
echo "[*] Running Ansible deployment..."
ansible-playbook -i "$inventory" "$playbook" --ask-pass --ask-become-pass ${LIMIT:+--limit "$LIMIT"}

# === Restore original inventory ===
mv "$inventory.bak" "$inventory"
