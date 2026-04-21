#!/usr/bin/env bash

NAME="ensure nodev option set on /tmp partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/tmp"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if findmnt -kn "/tmp" | grep -qv "nodev"; then
    if grep -Pq '^\s*\S+\s+/tmp\s+' /etc/fstab 2>/dev/null; then
        sed -i '/\s\/tmp\s/s/defaults/defaults,nodev/' /etc/fstab
    fi
    mount -o remount,nodev /tmp 2>/dev/null

    if findmnt -kn "/tmp" | grep -qv "nodev"; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0