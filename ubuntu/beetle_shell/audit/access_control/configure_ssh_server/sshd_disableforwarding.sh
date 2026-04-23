#!/usr/bin/env bash

NAME="sshd DisableForwarding config"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_DISABLEFORWARDING_EXPECTED:-yes}"

flag=1

# Fail if DisableForwarding is explicitly set to no
if sshd -T 2>/dev/null | grep -Piq '^disableforwarding\s+no'; then
    flag=0
fi

# If Match blocks exist, ensure the effective value is not overriding to no
if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if sshd -T -C user="$USER" 2>/dev/null | grep -Piq '^disableforwarding\s+no'; then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
