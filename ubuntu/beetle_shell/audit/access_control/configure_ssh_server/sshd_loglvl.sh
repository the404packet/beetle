#!/usr/bin/env bash

NAME='sshd LogLevel config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

# Allowed values from JSON: ["INFO","VERBOSE"] — stored as pipe-separated string
ALLOWED_RAW="${SSHD_LOGLEVEL_ALLOWED:-INFO|VERBOSE}"

value=$(sshd -T 2>/dev/null | awk '/^loglevel/ {print toupper($2)}')

if echo "$value" | grep -Piq "^(${ALLOWED_RAW})$"; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
