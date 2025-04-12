#!/bin/bash

# ===== config =====
db_user="sysadmin"
db_host="localhost"
target_user="username"

# prompt securely for mysql root password
read -s -p "Enter mysql $user password: " db_pass
echo
read -s -p "Enter new password for target user" new_pass1
read -s -p "Confirm new password for target user" new_pass2

if [ "$new_pass1" != "$new_pass2" ]; then
    echo "Passwords do not match!"
    exit 1
fi

# ===== change password =====
mysql -u"$db_user" -p"$db_pass" -h"$db_host" <<EOF
ALTER USER '$target_user'@'localhost' IDENTIFIED BY '$new_pass1';
FLUSH PRIVILEGES;
EOF

echo "password for mysql user '$target_user' has been changed."