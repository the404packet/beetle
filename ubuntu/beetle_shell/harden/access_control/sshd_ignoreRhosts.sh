#!/usr/bin/env bash

NAME='sshd IgnoreRhosts set to yes'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED="${SSHD_IGNORERHOSTS_EXPECTED:-yes}"
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*IgnoreRhosts\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Ii]gnore[Rr]hosts\s.*|IgnoreRhosts $EXPECTED|" "$SSHD_CONFIG"
else
    echo "IgnoreRhosts $EXPECTED" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*IgnoreRhosts\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Ii]gnore[Rr]hosts\s.*|IgnoreRhosts $EXPECTED|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^ignorerhosts/ {print $2}')

if [[ "$value" == "$EXPECTED" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
