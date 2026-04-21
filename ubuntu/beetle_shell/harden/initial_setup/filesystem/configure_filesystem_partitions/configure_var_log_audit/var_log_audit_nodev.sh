#!/usr/bin/env bash

NAME="ensure nodev option set on /var/log/audit partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/var/log/audit"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if findmnt -kn "/var/log/audit" | grep -qv "nodev"; then
    if grep -Pq '^\s*\S+\s+/var/log/audit\s+' /etc/fstab 2>/dev/null; then
        sed -i '/\s\/var/log/audit\s/s/defaults/defaults,nodev/' /etc/fstab
    fi
    mount -o remount,nodev /var/log/audit 2>/dev/null

    if findmnt -kn "/var/log/audit" | grep -qv "nodev"; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0