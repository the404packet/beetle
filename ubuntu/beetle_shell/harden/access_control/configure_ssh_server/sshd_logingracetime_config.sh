#!/usr/bin/env bash

NAME='sshd LoginGraceTime config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

GRACE_MIN="${SSHD_LOGINGRACETIME_MIN:-1}"
GRACE_MAX="${SSHD_LOGINGRACETIME_MAX:-60}"
TARGET="${SSHD_LOGINGRACETIME_VALUE:-60}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*LoginGraceTime\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Ll]ogin[Gg]race[Tt]ime\s.*|LoginGraceTime $TARGET|" "$SSHD_CONFIG"
else
    echo "LoginGraceTime $TARGET" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*LoginGraceTime\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Ll]ogin[Gg]race[Tt]ime\s.*|LoginGraceTime $TARGET|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^logingracetime/ {print $2}')

if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= GRACE_MIN && value <= GRACE_MAX )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
