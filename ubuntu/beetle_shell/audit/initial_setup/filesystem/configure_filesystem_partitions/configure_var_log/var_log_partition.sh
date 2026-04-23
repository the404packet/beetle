#!/usr/bin/env bash

NAME="ensure /var/log is a separate partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

idx=$(get_partition_idx "/var/log")
unit_var="FP_${idx}_systemd_unit"
unit="${!unit_var}"

if ! is_partition_mounted "/var/log"; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

if [ -n "$unit" ]; then
    status=$(systemctl is-enabled "$unit" 2>/dev/null)
    if [[ "$status" == "masked" || "$status" == "disabled" ]]; then
        echo -e "${RED}NOT HARDENED${RESET}"
        exit 0
    fi
fi

echo -e "${GREEN}HARDENED${RESET}"
exit 0