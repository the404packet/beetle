#!/usr/bin/env bash

NAME='ensure sudo authentication timeout is configured correctly'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_TIMEOUT="${SUDO_TIMESTAMP_TIMEOUT_MAX:-15}"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

flag=1

# Check explicitly configured timeout values
while read -r val; do
    if [[ "$val" == "-1" ]] || (( val > MAX_TIMEOUT )); then
        flag=0
        break
    fi
done < <(grep -roP "timestamp_timeout=\K[0-9-]*" /etc/sudoers* 2>/dev/null)

# If no explicit timeout set check the sudo default
if ! grep -roP "timestamp_timeout=" /etc/sudoers* 2>/dev/null | grep -q .; then
    default_timeout=$(sudo -V 2>/dev/null | grep -oP "Authentication timestamp timeout:\s*\K[0-9]+")
    if [[ -n "$default_timeout" ]] && (( default_timeout > MAX_TIMEOUT )); then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0