#!/usr/bin/env bash

NAME='sshd MaxSessions config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_SESSIONS="${SSHD_MAXSESSIONS_MAX:-10}"
TARGET="${SSHD_MAXSESSIONS_VALUE:-$MAX_SESSIONS}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*MaxSessions\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Mm]ax[Ss]essions\s.*|MaxSessions $TARGET|" "$SSHD_CONFIG"
else
    echo "MaxSessions $TARGET" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*MaxSessions\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Mm]ax[Ss]essions\s.*|MaxSessions $TARGET|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^maxsessions/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= MAX_SESSIONS )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
