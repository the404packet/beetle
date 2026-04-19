#!/usr/bin/env bash

NAME='sshd PermitEmptyPasswords config'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED="${SSHD_PERMITEMPTYPASSWORDS_EXPECTED:-no}"

flag=1

if sshd -T 2>/dev/null | grep -Piq "^permitemptypasswords\s+(?!${EXPECTED})"; then
    flag=0
fi

if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if sshd -T -C user="$USER" 2>/dev/null | \
       grep -Piq "^permitemptypasswords\s+(?!${EXPECTED})"; then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
