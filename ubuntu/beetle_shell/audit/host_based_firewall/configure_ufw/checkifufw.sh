#!/bin/bash

dpkg-query -s ufw &>/dev/null && echo "ufw is installed"
SEVERITY=""
if command -v ufw >/dev/null 2>&1; then
	echo "Ufw already installed ."
else
	echo "Ufw not installed. Installing ..."
	
	sudo apt update
	sudo apt install -y ufw
	
	if command -v ufw >/dev/null 2>&1; then
		echo "Ufw installed ."
		sudo ufw enable
	else
		echo "Error in installing Ufw"
		exit 1
	fi
fi
