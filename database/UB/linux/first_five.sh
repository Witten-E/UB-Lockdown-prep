#!/bin/bash

#   ./first_five.sh -l            # Run in headless mode (no prompts, automated)
# If run in headless mode, expects config.env file in the same directory with:
# headless_pass="your_password_here"

personal_user="sockpuppet"
backup_user="puppetmaster"
script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
log_file=./blue_init.log
exec > >(tee -a "$log_file") 2>&1

if [ -f "$script_dir/config.env" ]; then
    source "$script_dir/config.env"
else
    echo "No config.env file found in $script_dir"
fi


# ===== Detect Distro =====
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro="${ID,,}"
else
    distro="unknown"
fi

# ===== Update System =====
update_system() {
    echo "[*] Updating system"
    case "$distro" in
        ubuntu|debian)
            if apt-get update -y &>/dev/null; then
                echo "[V] Updated via apt"
            else
                echo "[X] Update failed"
            fi
        ;;
        rhel|centos|fedora)
            if command -v dnf &>/dev/null; then
                if dnf up -y; then
                    echo "[V] Updated via dnf"
                else
                    echo "[X] Update failed"
                fi
            else
                if yum update -y &>/dev/null; then
                    echo "[V] Updated via yum"
                else
                    echo "[X] Update failed"
                fi
            fi
        ;;
        arch|manjaro)
            if pacman -Syu --noconfirm &>/dev/null; then
                echo "[V] Updated via pacman"
            else
                echo "[X] Update failed"
            fi
        ;;
        *)
            echo "Unsupported distro: $distro"
        ;;
    esac
}

# ===== Create blue team users =====
make_blue_users() {
    echo "[*] Creating blue team users"
    # Create Personal User
    if ! id "$personal_user" &>/dev/null; then
        echo "[*] Creating personal user: $personal_user"
        adduser --disabled-password --comment "" "$personal_user"
    fi
    
    # Create Backup User
    if ! id "$backup_user" &>/dev/null; then
        echo "[*] Creating backup user: $backup_user"
        adduser --disabled-password --comment "" "$backup_user"
    fi
    
    # Grant sudo privileges
    echo "[*] Adding both users to the sudo group..."
    usermod -aG sudo "$personal_user"
    usermod -aG sudo "$backup_user"
    
    echo "[Completed user creation]"
}

change_passwords() {
    echo "[*] Changing passwords..."
    
    if [ "$headless" = false ]; then
        if ! "$script_dir/passwords/change_all_passwords.sh" $excluded_from_pw_change; then
            exit 1
        fi
    else
        if [ -z "$headless_pass" ]; then
            echo "[X] Headless mode requires 'headless_pass' in config.env"
            exit 1
        else
            "$script_dir/passwords/change_all_passwords.sh" -l -p "$headless_pass" $excluded_from_pw_change
            unset headless_pass
        fi
    fi
}

sshd_set() {
    local key="$1"
    local val="$2"
    if grep -q "^$key" /etc/ssh/sshd_config; then
        sed -i "s/^$key.*/$key $val/" /etc/ssh/sshd_config
    else
        echo "$key $val" >> /etc/ssh/sshd_config
    fi
}

harden_ssh() {
    echo "[*] Hardening sshd_config"
    
    sshd_set "PermitRootLogin" "no"
    sshd_set "MaxAuthTries" "3"
    sshd_set "PermitEmptyPasswords" "no"
    sshd_set "X11Forwarding" "no"
    sshd_set "IgnoreRhosts" "yes"
    sshd_set "HostbasedAuthentication" "no"
    
    systemctl restart sshd || systemctl restart ssh
    
    echo "[V] Done hardening sshd_config"
}

disable_kernel_modules() {
    echo -e "[*] Disabling the loading of kernel modules"

    sysctl -w kernel.modules_disabled=1 > /dev/null
    if ! grep -q '^kernel.modules_disabled=1' /etc/sysctl.conf; then
        echo 'kernel.modules_disabled=1' >> /etc/sysctl.conf
    fi
    echo "[V] Disablied loading of kernel modules"
}

persist_sysctl_setting() {
    local key="$1"
    local value="$2"
    if ! grep -q "^${key}=" /etc/sysctl.conf; then
        echo "${key}=${value}" >> /etc/sysctl.conf
    fi
}

disable_ipv6_and_forwarding() {
    echo -e "[*] Disabling ipv6 and ip forwarding"

    # Disable
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    sysctl -w net.ipv4.ip_forward=0
    sysctl -w net.ipv6.conf.all.forwarding=0

    # Persist
    persist_sysctl_setting net.ipv6.conf.all.disable_ipv6 1
    persist_sysctl_setting net.ipv6.conf.default.disable_ipv6 1
    persist_sysctl_setting net.ipv4.ip_forward 0
    persist_sysctl_setting net.ipv6.conf.all.forwarding 0

    echo "[V] Disabled ipv6 and ip forwarding"
}

remove_risky_binaries() {
    echo -e "[*] Removing risky binaries (telnet, nc)"

    for bin in telnet nc; do
        path=$(command -v "$bin" 2>/dev/null)
        if [ -n "$path" ]; then
            echo "[*] Removing $bin at $path"
            rm -f "$path"
        fi
    done

    echo -e "[V] Removed risky binaries"
}

lock_scheduled_tasks() {
    echo "[*] Locking down cron and systemd timers"

    # Lock /etc/crontab if it exists
    [ -f /etc/crontab ] && chattr +i /etc/crontab 2>/dev/null

    # Lock /etc/cron.d and then the files in it, if they are not created by init_hungrctl.sh
    [ -d /etc/cron.d ] && chattr +i /etc/cron.d 2>/dev/null
    for file in /etc/cron.d/*; do
        [ -e "$file" ] || continue
        case "$file" in
            /etc/cron.d/run_cron|/etc/cron.d/fallback_cron)
                echo "[i] Skipping managed cron file: $file"
                ;;
            *)
                chattr +i "$file" 2>/dev/null
                ;;
        esac
    done

    echo "[V] Locked scheduled tasks"
}

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
    trap 'rm -f "$script_dir/config.env"' EXIT
fi

update_system
make_blue_users
change_passwords
harden_ssh
"$script_dir/hardening/history_timestamps.sh"
if [ "$headless" = true ]; then
    # Run in a pseudo-terminal to preserve
    script -qfc "$script_dir/firewall/nft_config.sh -l -ifa" /dev/null
else
    # Interactive: run in a pseudo-terminal
    script -qfc "$script_dir/firewall/nft_config.sh -ifa" /dev/null
fi
disable_kernel_modules
disable_ipv6_and_forwarding
remove_risky_binaries
lock_scheduled_tasks

echo "[V] Initialization complete at $(date) on $(hostname)"