#!/bin/bash

#
#edit service file to add the actual script path
#
mv ./services-startup.service /etc/systemd/system/
systemctl daemon-reload 
systemctl enable services-startup.service 
