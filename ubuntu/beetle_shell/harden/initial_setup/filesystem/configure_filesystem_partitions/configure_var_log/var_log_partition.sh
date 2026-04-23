#!/usr/bin/env bash

NAME="ensure /var/log is a separate partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

idx=$(get_partition_idx "/var/log")
unit_var="FP_${idx}_systemd_unit"
unit="${!unit_var}"

if [ -n "$unit" ]; then
    systemctl unmask "$unit" 2>/dev/null
    systemctl enable "$unit" 2>/dev/null
fi

if ! is_partition_mounted "/var/log"; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0