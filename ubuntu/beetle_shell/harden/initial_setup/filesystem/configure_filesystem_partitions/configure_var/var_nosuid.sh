#!/usr/bin/env bash

NAME="ensure nosuid option set on /var partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/var"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if findmnt -kn "/var" | grep -qv "nosuid"; then
    if grep -Pq '^\s*\S+\s+/var\s+' /etc/fstab 2>/dev/null; then
        sed -i '/\s\/var\s/s/defaults/defaults,nosuid/' /etc/fstab
    fi
    mount -o remount,nosuid /var 2>/dev/null

    if findmnt -kn "/var" | grep -qv "nosuid"; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0