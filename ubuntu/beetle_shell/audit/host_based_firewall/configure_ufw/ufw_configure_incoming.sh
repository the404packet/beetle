#!/bin/bash

NAME="ufw-configure-incoming deny incoming"
SEVERITY="basic" # if not basic i will give it name as 'placeholder' so i know to change

RED="\e[37;41m"
GREEN="\e[37;42m"
RESET="\e[0m"

set -e  # Enable the 'exit on error' mode

echo "=== Configuring Incoming ==================================================="
#check if ufw exists and if not then echo comamnd to install ufw
if ! command -v ufw >/dev/null 2>&1; then
	printf "UFW is ${RED}not INSTALLED${RESET}"
	echo "Use ./ufw_audit.sh command to set up ufw" #placeholder for now
	exit 1
fi

current_policy_incoming=$(ufw status verbose | grep 'Default:' | awk -F',' '{print $1}' | awk -F': ' '{print $2}' | xargs)


#for debugging => echo "Current Default INCOMING policy: $current_policy_incoming"

if [[ "$current_policy_incoming" == "deny (incoming)" || "$current_policy_incoming" == "reject (incoming)" ]]; then
	printf "Incoming Policy :  ${GREEN}DENY Incoming (Secure)${RESET}\n"
	exit 0
else
	printf "Incoming Policy :  ${RED}NOT (Secure)${RESET}\n"
	echo "Denying Incoming.... "
	
	ufw default deny incoming #MAIN 
	
	new_policy_incoming=$(ufw status verbose | grep 'Default:' | awk -F',' '{print $1}' | awk -F': ' '{print $2}' | xargs)
	#for debugging => echo "Current Default INCOMING policy: $new_policy_incoming"
	
	if [[ "$new_policy_incoming" == "deny (incoming)" || "$new_policy_incoming" == "reject (incoming)" ]]; then
		printf "Incoming Policy :  ${GREEN}DENY Incoming (Secure)${RESET}\n"
	else 
		printf "WARNING :  ${RED}NOT (Secure)${RESET} Denying ${RED}FAILED${RESET}\n"
		exit 2
	fi
fi



