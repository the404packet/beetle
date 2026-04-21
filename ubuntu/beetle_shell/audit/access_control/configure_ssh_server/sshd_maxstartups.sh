#!/usr/bin/env bash

NAME='sshd MaxStartups config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

START_MAX="${SSHD_MAXSTARTUPS_START_MAX:-10}"
RATE_MAX="${SSHD_MAXSTARTUPS_RATE_MAX:-30}"
FULL_MAX="${SSHD_MAXSTARTUPS_FULL_MAX:-60}"

flag=1

value=$(sshd -T 2>/dev/null | awk '/^maxstartups/ {print $2}')

if [[ "$value" =~ ^[0-9]+:[0-9]+:[0-9]+$ ]]; then
    IFS=':' read -r start rate full <<< "$value"
    if (( start > START_MAX || rate > RATE_MAX || full > FULL_MAX )); then
        flag=0
    fi
else
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
