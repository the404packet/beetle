#!/usr/bin/env bash

NAME="sshd HostbasedAuthentication set to no"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_HOSTBASEDAUTHENTICATION_EXPECTED:-no}"

flag=1

if sshd -T 2>/dev/null | grep -Piq "^hostbasedauthentication\s+(?!${EXPECTED})"; then
    flag=0
fi

if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if sshd -T -C user="$USER" 2>/dev/null | \
       grep -Piq "^hostbasedauthentication\s+(?!${EXPECTED})"; then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
