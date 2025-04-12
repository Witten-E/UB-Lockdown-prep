#! bin/bash

# usage: ./ubuntu_ufw.sh <PORTS/SERVICES>
# use if nftables or other script doesn't work ig

if ! systemctl list-unit-files --type=service | grep -q "ufw.service"; then
    # Install if not already installed
    sudo apt install ufw
else
    # Reset for a clean slate. Erases rules + turns off ufw
    sudo ufw reset
fi

# Turn UFW on
sudo ufw enable

# Deny all connections by default
sudo ufw default deny

# Rules go under here
# Rules can be port numbers or services (22, ssh, etc), i think services should be lowercase
rules=("$@")
for rule in "${rules[@]}"; do
    echo "sudo ufw allow $rule"
done