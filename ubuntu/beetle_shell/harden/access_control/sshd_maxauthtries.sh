#!/usr/bin/env bash

NAME='sshd MaxAuthTries config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_TRIES="${SSHD_MAXAUTHTRIES_MAX:-4}"
TARGET="${SSHD_MAXAUTHTRIES_VALUE:-$MAX_TRIES}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*MaxAuthTries\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Mm]ax[Aa]uth[Tt]ries\s.*|MaxAuthTries $TARGET|" "$SSHD_CONFIG"
else
    echo "MaxAuthTries $TARGET" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*MaxAuthTries\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Mm]ax[Aa]uth[Tt]ries\s.*|MaxAuthTries $TARGET|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^maxauthtries/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= MAX_TRIES )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
