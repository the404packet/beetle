#!/usr/bin/env bash

NAME="sshd LogLevel config"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

ALLOWED_RAW="${SSHD_LOGLEVEL_ALLOWED:-INFO|VERBOSE}"
TARGET="${SSHD_LOGLEVEL_VALUE:-INFO}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -Piq '^\s*LogLevel\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Ll]og[Ll]evel\s.*|LogLevel $TARGET|" "$SSHD_CONFIG"
else
    echo "LogLevel $TARGET" >> "$SSHD_CONFIG"
fi

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*LogLevel\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Ll]og[Ll]evel\s.*|LogLevel $TARGET|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

value=$(sshd -T 2>/dev/null | awk '/^loglevel/ {print toupper($2)}')

if echo "$value" | grep -Piq "^(${ALLOWED_RAW})$"; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
