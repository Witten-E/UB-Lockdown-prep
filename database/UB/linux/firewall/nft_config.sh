#!/bin/bash

# nft_config.sh - Script to manage nftables installation, configuration, and persistence
# Usage:
#   ./nft_config.sh -i      # Install and enable nftables
#   ./nft_config.sh -a      # Apply default nftables ruleset. If the script is not killed (ctrl + C), it will revert in 15 seconds
#   ./nft_config.sh -s      # Save current ruleset to /etc/nftables.conf
#   ./nft_config.sh -r      # Restore nftables rules from /etc/nftables.backup
#   ./nft_config.sh -f      # Flush current nftables ruleset
#   ./nft_config.sh -l      # Headless mode
#   ./nft_config.sh -ia     # Install and apply rules in one step
#   ./nft_config.sh -rs     # Restore from backup and save it to config for persistence
#   ./nft_config.sh -ifa    # Flush, install, and apply rules in one step
#   ./nft_config.sh -lifa   # Headless install
#
#   THIS SCRIPT INCLUDES A DEAD MAN'S SWITCH. AFTER APPLYING DEFAULT RULES, PRESS CTRL + C TO APPLY THEM. THIS STOPS YOU FROM LOCKING YOURSELF OUT.

red='\e[31m'
green='\e[32m'
yellow='\e[33m'
bold='\e[1m'
reset='\e[0m'

headless=false
dms=true

script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
config_file="$script_dir/default_rules.conf"

# ===== Check for root =====
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

# Normalize and detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID" | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# Install nftables based on distro
install_nftables() {
    case "$1" in
        *ubuntu*|*debian*)
            apt-get update
            apt-get install -y nftables
        ;;
        *fedora*)
            dnf install -y nftables
        ;;
        *centos*|*rhel*|*rocky*|*almalinux*)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y nftables
            else
                yum install -y epel-release
                yum install -y nftables
            fi
        ;;
        *arch*)
            pacman -Sy --noconfirm nftables
        ;;
        *suse*|*opensuse*|*sles*)
            zypper install -y nftables
        ;;
        *)
            echo -e "${red}Unsupported distribution: $1${reset}"
            exit 1
        ;;
    esac
}

# Enable and start the nftables service
enable_nftables() {
    systemctl enable --now nftables
}

# Flush current ruleset
flush_ruleset() {
    if nft list ruleset | grep -q 'table'; then
        echo -e "${yellow}Warning: Existing nftables rules detected. Backing them up to /etc/nftables.backup${reset}"
        nft list ruleset > /etc/nftables.backup
    fi
    echo -e "${yellow}Flushing current nftables ruleset...${reset}"
    nft flush ruleset
}

# Apply a default nftables ruleset (with backup if rules exist)
apply_default_ruleset() {
    local disarmed=false
    
    if nft list ruleset | grep -q 'table' && [ ! -s "/etc/nftables.backup" ]; then
        echo -e "${yellow}Warning: Existing nftables rules detected. Backing them up to /etc/nftables.backup${reset}"
        nft list ruleset > /etc/nftables.backup
    fi
    
    if [ "$headless" = true ]; then
        echo -e "${green}[HEADLESS] Applying default ruleset...${reset}"
        nft -f "$config_file"
    else
        if [ -f /etc/nftables.backup ]; then
            if diff -q /etc/nftables.backup <(tail -n +2 "$config_file"); then
                echo -e "${green}Ruleset matches backup."
            else
                diff -u /etc/nftables.backup <(tail -n +2 "$config_file")
                read -p "Update ruleset to default configuration? [y/N]: " update
                
                if [[ "$update" =~ ^[Yy]$ ]]; then
                    echo -e "${green}Applying basic default nftables ruleset...${reset}"
                    nft -f "$config_file"
                else
                    echo -e "${red}Leaving firewall ruleset as is${reset}"
                fi
            fi
        fi
    fi
    if [ "$dms" = true ]; then
        # Lockout protection (Dead Man's Switch)
        echo -e "${green}[DMS] Press CTRL + C to persist the ruleset. Failure to do so will result in a rollback for lockout protection.${reset}"
        # Persist on SIGINT (Ctrl + C)
        trap 'echo -e "${green}[DMS] SIGINT received. Persisting ruleset...${reset}"; disarmed=true;' SIGINT
        # Else, wait 15 seconds and rollback
        sleep 15
        if [ "$disarmed" = true ]; then
            echo -e "${green}[DMS] Ruleset persisted due to SIGINT.${reset}"
            nft list ruleset > /etc/nftables.conf
        else
            echo -e "${red}[DMS] No persist signal received. Rolling back firewall ruleset...${reset}"
            restore_backup_ruleset
            save_current_ruleset
        fi
    else
        nft list ruleset > /etc/nftables.conf
    fi
}

# Save current ruleset to config file
save_current_ruleset() {
    echo -e "${green}Saving current ruleset to /etc/nftables.conf...${reset}"
    nft list ruleset > /etc/nftables.conf
}

# Restore rules from backup file
restore_backup_ruleset() {
    if [ -f /etc/nftables.backup ]; then
        echo -e "${yellow}Restoring ruleset from /etc/nftables.backup...${reset}"
        nft flush ruleset
        nft -f /etc/nftables.backup
        echo -e "${green}Restored successfully.${reset}"
    else
        echo -e "${red}No backup file found at /etc/nftables.backup${reset}"
        exit 1
    fi
}

# Display help message
display_help() {
    echo -e "${bold}Usage: $0 [-i] [-a] [-s] [-r] [-f]${reset}"
    echo "  -i    Install and enable nftables"
    echo "  -a    Apply default nftables ruleset"
    echo "  -s    Save current in-memory ruleset to /etc/nftables.conf"
    echo "  -r    Restore nftables ruleset from /etc/nftables.backup"
    echo "  -f    Flush current nftables ruleset"
    echo "  -l    Headless mode (auto-apply ruleset without prompting)"
    echo "  -n    No Dead Man's Switch. USE WITH CAUTION"
    echo "  -h    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -ia     # Install and apply default ruleset"
    echo "  $0 -rs     # Restore from backup and save it to config for persistence"
    echo "  $0 -f      # Flush current ruleset only"
    echo "  $0 -ifa    # Flush, install, and apply rules in one step"
    exit 1
}

# ===== Check for nft installation =====
if ! command -v nft >/dev/null 2>&1; then
    echo -e "${red}nft is not installed. Run with -i first.${reset}"
    exit 1
fi

# Parse options with getopts
while getopts "iasrfln" opt; do
    case "$opt" in
        i)
            distro=$(detect_distro)
            echo -e "${green}Detected distro: $distro${reset}"
            install_nftables "$distro"
            enable_nftables
        ;;
        a)
            apply=true
        ;;
        s)
            save=true
        ;;
        r)
            restore=true
        ;;
        f)
            flush=true
        ;;
        l)
            headless=true
        ;;
        n)
            dms=false
        ;;
        h)
            help=true
        ;;
        *)
            display_help
        ;;
    esac
    found=true
done

[ "$flush" = true ] && flush_ruleset
[ "$apply" = true ] && apply_default_ruleset
[ "$save" = true ] && save_current_ruleset
[ "$restore" = true ] && restore_backup_ruleset


# If no flags were provided
if [ -z "$found" ] || [ "$help" = true ]; then
    display_help
fi
