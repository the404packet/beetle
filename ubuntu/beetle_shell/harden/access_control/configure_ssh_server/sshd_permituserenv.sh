#!/usr/bin/env bash

NAME="sshd PermitUserEnvironment config"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_PERMITUSERENVIRONMENT_EXPECTED:-no}"
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*PermitUserEnvironment\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Pp]ermit[Uu]ser[Ee]nvironment\s.*|PermitUserEnvironment $EXPECTED|" "$SSHD_CONFIG"
else
    echo "PermitUserEnvironment $EXPECTED" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*PermitUserEnvironment\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Pp]ermit[Uu]ser[Ee]nvironment\s.*|PermitUserEnvironment $EXPECTED|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^permituserenvironment/ {print $2}')

if [[ "$value" == "$EXPECTED" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
