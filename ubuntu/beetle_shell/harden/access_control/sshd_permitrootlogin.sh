#!/usr/bin/env bash

NAME='sshd PermitRootLogin config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_PERMITROOTLOGIN_EXPECTED:-no}"
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*PermitRootLogin\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Pp]ermit[Rr]oot[Ll]ogin\s.*|PermitRootLogin $EXPECTED|" "$SSHD_CONFIG"
else
    echo "PermitRootLogin $EXPECTED" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*PermitRootLogin\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Pp]ermit[Rr]oot[Ll]ogin\s.*|PermitRootLogin $EXPECTED|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^permitrootlogin/ {print $2}')

if [[ "$value" == "$EXPECTED" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
