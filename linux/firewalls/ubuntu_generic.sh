#! bin/bash

if ! systemctl list-unit-files --type=service | grep -q "ufw.service"
then # Install if not already installed
    sudo apt install ufw
else # Reset if already installed
    sudo ufw reset
fi
# Turn UFW on
sudo ufw enable

sudo ufw default deny

# Rules go under here