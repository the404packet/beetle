#!/bin/bash

NAME="ufw-configure-routed deny routed"
SEVERITY="basic" # if not basic i will give it name as 'placeholder' so i know to change

RED="\e[37;41m"
GREEN="\e[37;42m"
RESET="\e[0m"

set -e  # Enable the 'exit on error' mode

echo "=== Configuring Routed ====================================================="

# Check if ufw exists and if not, then echo the command to install ufw
if ! command -v ufw >/dev/null 2>&1; then
    printf "UFW is ${RED}not INSTALLED${RESET}\n"
    echo "Use ./ufw_audit.sh and ./checkifufw.sh command to set up ufw" # Placeholder for now we will change the actual command names later
    exit 1
fi


# Check and configure routed policy (which is disabled by default)
current_policy_routed=$(ufw status verbose | grep 'Default:' | awk -F',' '{print $2}' | awk -F': ' '{print $2}' | xargs)

# Debugging: echo "Current Default ROUTED policy: $current_policy_routed"
if [[ "$current_policy_routed" == "deny (routed)" || "$current_policy_routed" == "reject (routed)" ]]; then
    printf "Routed Policy :  ${GREEN}DENY Routed (Secure)${RESET}\n"
else
    printf "Routed Policy :  ${RED}NOT (Secure)${RESET}\n"
    echo "Denying Routed...."
    
    ufw default deny routed  # Main stuff
    
    new_policy_routed=$(ufw status verbose | grep 'Default:' | awk -F',' '{print $2}' | awk -F': ' '{print $2}' | xargs)

    # Debugging: echo "Current Default ROUTED policy: $new_policy_routed"
    if [[ "$new_policy_routed" == "deny (routed)" || "$new_policy_routed" == "reject (routed)" ]]; then
        printf "Routed Policy :  ${GREEN}DENY Routed (Secure)${RESET}\n"
    else
        printf "WARNING :  ${RED}NOT (Secure)${RESET} Denying ${RED}FAILED${RESET}\n"
        exit 3
    fi
fi

