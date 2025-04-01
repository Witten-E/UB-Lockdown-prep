#!/bin/bash

# Backup Tool
#
# Usage:
#   ./backup_tool.sh [options]
#
# Options:
#   -c               Set up a cron job to run this script automatically
#   -d <dirs>        Comma-separated list of directories to back up (default: /etc,/var/log,/home,/opt)
#   -t <schedule>    Cron schedule string (e.g., "0 2 * * *")
#   -r <file>        Restore from a specified backup archive (.tar.gz)
#
# Examples:
#   ./backup_tool.sh -c -d "/etc,/opt" -t "0 * * * *"
#   ./backup_tool.sh -r /var/backups/blue-team/backup_2025-04-01_14-35-08.tar.gz


# === COLORS ===
red="\033[0;31m"
green="\033[0;32m"
yellow="\033[1;33m"
blue="\033[0;34m"
reset="\033[0m"

# === REQUIRE ROOT ===
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}ERROR: This script must be run as root.${reset}"
    exit 1
fi

# === DEFAULT CONFIGURATION ===
default_dirs="/etc,/var/log,/home,/opt"
backup_dir="/var/backups/blue-team"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
backup_name="backup_$timestamp.tar.gz"
script_path="$(realpath "$0")"
cron_schedule="0 * * * *"
setup_cron=false
custom_dirs="$default_dirs"
restore_file=""
restore_mode=false

# === SETUP BACKUP DIRECTORY SECURELY ===
setup_backup_dir() {
    log_file="$backup_dir/backup_log.txt"

    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
        if [ $? -ne 0 ]; then
            echo -e "${red}ERROR: Failed to create backup directory: $backup_dir${reset}"
            exit 1
        fi
        echo -e "${blue}Created backup directory at $backup_dir${reset}"
    fi

    chmod 700 "$backup_dir"
    if [ $? -ne 0 ]; then
        echo -e "${red}ERROR: Failed to set permissions on $backup_dir${reset}"
        exit 1
    fi
}

# === BACKUP FUNCTION ===
perform_backup() {
    IFS=',' read -ra dir_array <<< "$custom_dirs"
    echo "[$(date)] Starting backup..." >> "$log_file"
    tar -czpf "$backup_dir/$backup_name" "${dir_array[@]}" 2>>"$log_file"

    if [ $? -eq 0 ]; then
        echo "[$(date)] Backup completed: $backup_name" >> "$log_file"
        echo -e "${green}Backup successful: $backup_name${reset}"
    else
        echo "[$(date)] Backup FAILED." >> "$log_file"
        echo -e "${red}Backup failed. Check $log_file for details.${reset}"
    fi
}

# === RESTORE FUNCTION ===
restore_backup() {
    if [ -z "$restore_file" ]; then
        echo -e "${red}ERROR: No restore file specified with -r option.${reset}"
        exit 1
    fi

    if [ ! -f "$restore_file" ]; then
        echo -e "${red}ERROR: Specified backup file does not exist: $restore_file${reset}"
        exit 1
    fi

    echo -e "${blue}Restoring from backup: $restore_file${reset}"
    tar -xzpf "$restore_file" -C / 2>>"$log_file"

    if [ $? -eq 0 ]; then
        echo -e "${green}Restore completed successfully.${reset}"
    else
        echo -e "${red}Restore failed. Check $log_file for details.${reset}"
        exit 1
    fi
}

# === CRON FUNCTION ===
add_cron_job() {
    if ! command -v crontab &> /dev/null; then
        echo -e "${red}ERROR: crontab not found. Please install cron.${reset}"
        exit 1
    fi
    (crontab -l 2>/dev/null | grep -v "$script_path" ; echo "$cron_schedule bash $script_path -d \"$custom_dirs\"") | crontab -
    echo -e "${green}Cron job set: $cron_schedule bash $script_path -d \"$custom_dirs\"${reset}"
}

# === USAGE FUNCTION ===
usage() {
    echo -e "${yellow}Usage:${reset} $0 [options]\n"
    echo -e "${yellow}Options:${reset}"
    echo -e "  ${green}-c${reset}            Set up a cron job to run this script"
    echo -e "  ${green}-d <dirs>${reset}     Comma-separated list of directories to back up"
    echo -e "  ${green}-t <schedule>${reset} Cron schedule string (e.g., '0 2 * * *')"
    echo -e "  ${green}-r <file>${reset}     Restore from a specified backup file"
    echo -e "\nExamples:"
    echo -e "  $0 -c -d \"/etc,/home\" -t \"0 * * * *\""
    echo -e "  $0 -r /var/backups/blue-team/backup_2025-04-01_14-35-08.tar.gz"
    exit 1
}

# === PARSE OPTIONS ===
while getopts "cd:t:r:" opt; do
    case $opt in
        c) setup_cron=true ;;
        d) custom_dirs="$OPTARG" ;;
        t) cron_schedule="$OPTARG" ;;
        r) restore_file="$OPTARG" ; restore_mode=true ;;
        *) usage ;;
    esac
done

# === MAIN EXECUTION ===
setup_backup_dir

if $restore_mode; then
    restore_backup
    exit 0
fi

perform_backup

if $setup_cron; then
    add_cron_job
fi

