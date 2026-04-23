#!/usr/bin/env bash

NAME="sshd MaxStartups config"
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
TARGET="${SSHD_MAXSTARTUPS_VALUE:-10:30:60}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*MaxStartups\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Mm]ax[Ss]tartups\s.*|MaxStartups $TARGET|" "$SSHD_CONFIG"
else
    echo "MaxStartups $TARGET" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*MaxStartups\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Mm]ax[Ss]tartups\s.*|MaxStartups $TARGET|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
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
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
