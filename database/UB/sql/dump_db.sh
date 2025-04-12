#!/bin/bash

# TO RESTORE A DATABASE TO PREVIOUS STATE, RUN:
# mysql -u $user -p $target_db < dumpfile.sql

# ===== config =====
db_user="sysadmin"
db_pass="changeme"
output_dir="/var/backups/mysql"
timestamp="$(date +%F_%T)"
mkdir -p "$output_dir"

log_file="$output_dir/backup_log_$timestamp.txt"

# ===== dump each non-system database =====
databases=$(mysql -u"$db_user" -p"$db_pass" -e "show databases;" | grep -Ev "(Database|mysql|information_schema|performance_schema|sys)")

for db in $databases; do
    out_file="${output_dir}/${db}_${timestamp}.sql"
    if mysqldump -u"$db_user" -p"$db_pass" "$db" > "$out_file" 2>>"$log_file"; then
        echo "[ok] dumped $db to $out_file" >> "$log_file"
    else
        echo "[fail] failed to dump $db" >> "$log_file"
    fi
done

echo "[*] backup complete. logs written to $log_file"
