#!/usr/bin/env bash

NAME='sshd GSSAPIAuthentication set to no'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_GSSAPIAUTHENTICATION_EXPECTED:-no}"
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*GSSAPIAuthentication\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Gg][Ss][Ss][Aa][Pp][Ii][Aa]uthentication\s.*|GSSAPIAuthentication $EXPECTED|" "$SSHD_CONFIG"
else
    echo "GSSAPIAuthentication $EXPECTED" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*GSSAPIAuthentication\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Gg][Ss][Ss][Aa][Pp][Ii][Aa]uthentication\s.*|GSSAPIAuthentication $EXPECTED|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^gssapiauthentication/ {print $2}')

if [[ "$value" == "$EXPECTED" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
