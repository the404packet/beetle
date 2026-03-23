#!/bin/bash

NAME="ufw-check check whether ufw is up and running and if not enable and activate it"
SEVERITY="basic" # if not basic i will give it name as 'placeholder' so i know to change

RED="\e[37;41m"
GREEN="\e[37;42m"
RESET="\e[0m"

set -e  # Enable the 'exit on error' mode

echo "=== Checking UFW enable status ============================================="
if systemctl is-enabled ufw.service >/dev/null 2>&1; then
	printf "ufw.service already ${GREEN}enabled${RESET}"
else
	printf "ufw.service is ${RED}not enabled${RESET}"
	echo "enabling ... warning this will unmask UFW if masked "
	sudo systemctl unmask ufw.service || true #unmask if manually masked but warn beforehand
	sudo systemctl enable ufw.service
fi

echo "" #for the asthetics :)
echo "=== Checking UFW active status ============================================="
if systemctl is-active ufw.service >/dev/null 2>&1; then
	printf "ufw.service already ${GREEN}active${RESET}"
else
	printf "ufw.service is ${RED}not active${RESET}"
	echo "starting ... "
	sudo systemctl start ufw.service
fi

echo "" #for the asthetics :)
echo "=== Checking UFW Firewall status ==========================================="
if ufw status | grep -q "Status: active"; then
	printf "Fire wall is ${GREEN}active${RESET} on startup."
else
	printf "ufw.service is ${RED}not active${RESET} on startup"
	echo "force starting ... "
	sudo ufw --force enable
fi

echo "" #for the asthetics :)
echo "=== FINAL VERIFICATION ====================================================="
echo "UFW Service Enabled:     $(systemctl is-enabled ufw.service)"
echo "UFW Service Active:      $(systemctl is-active ufw.service)"
echo "Firewall Status:         $(ufw status)"
