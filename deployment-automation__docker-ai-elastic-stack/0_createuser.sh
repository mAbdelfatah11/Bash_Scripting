#!/bin/bash

read -p "Enter password for the new user: " PASSWORD

useradd -p $PASSWORD -G sudo -m -d /home/WB-Services -s /bin/bash WB-Services
#execute sudo commands without password
echo "WB-Services ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

su - WB-Services
