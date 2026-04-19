#!/usr/bin/env bash

NAME='sshd IgnoreRhosts set to yes'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED="${SSHD_IGNORERHOSTS_EXPECTED:-yes}"

flag=1

if sshd -T 2>/dev/null | grep -Piq "^ignorerhosts\s+(?!${EXPECTED})"; then
    flag=0
fi

if (( flag )) && \
   grep -Riq '^\s*Match\b' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
    if sshd -T -C user="$USER" 2>/dev/null | \
       grep -Piq "^ignorerhosts\s+(?!${EXPECTED})"; then
        flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
