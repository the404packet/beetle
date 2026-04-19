#!/usr/bin/env bash

NAME='sshd UsePAM config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_USEPAM_EXPECTED:-yes}"
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*UsePAM\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Uu]se[Pp][Aa][Mm]\s.*|UsePAM $EXPECTED|" "$SSHD_CONFIG"
else
    echo "UsePAM $EXPECTED" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*UsePAM\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Uu]se[Pp][Aa][Mm]\s.*|UsePAM $EXPECTED|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^usepam/ {print $2}')

if [[ "$value" == "$EXPECTED" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
