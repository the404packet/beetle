#!/usr/bin/env bash

NAME="ensure noexec option set on /var/tmp partition"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

if ! is_partition_mounted "/var/tmp"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if findmnt -kn "/var/tmp" | grep -qv "noexec"; then
    if grep -Pq '^\s*\S+\s+/var/tmp\s+' /etc/fstab 2>/dev/null; then
        sed -i '/\s\/var/tmp\s/s/defaults/defaults,noexec/' /etc/fstab
    fi
    mount -o remount,noexec /var/tmp 2>/dev/null

    if findmnt -kn "/var/tmp" | grep -qv "noexec"; then
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0