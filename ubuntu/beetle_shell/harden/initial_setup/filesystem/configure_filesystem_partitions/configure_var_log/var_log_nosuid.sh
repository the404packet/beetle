#!/usr/bin/env bash

NAME="ensure nosuid option set on /var/log partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/var/log"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if findmnt -kn "/var/log" | grep -qv "nosuid"; then
    if grep -Pq '^\s*\S+\s+/var/log\s+' /etc/fstab 2>/dev/null; then
        sed -i '/\s\/var/log\s/s/defaults/defaults,nosuid/' /etc/fstab
    fi
    mount -o remount,nosuid /var/log 2>/dev/null

    if findmnt -kn "/var/log" | grep -qv "nosuid"; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0