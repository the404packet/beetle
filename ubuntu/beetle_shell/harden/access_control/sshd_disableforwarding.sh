#!/usr/bin/env bash

NAME='sshd DisableForwarding config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_DISABLEFORWARDING_EXPECTED:-yes}"
SSHD_CONFIG="/etc/ssh/sshd_config"
flag=1

if grep -Piq '^\s*DisableForwarding\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Dd]isable[Ff]orwarding\s.*|DisableForwarding $EXPECTED|" "$SSHD_CONFIG"
else
    echo "DisableForwarding $EXPECTED" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*DisableForwarding\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Dd]isable[Ff]orwarding\s.*|DisableForwarding $EXPECTED|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
if sshd -T 2>/dev/null | grep -Piq '^disableforwarding\s+no'; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
