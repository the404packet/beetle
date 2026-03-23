#!/usr/bin/env bash

NAME='sshd MaxStartups config'
SEVERITY="basic"

flag=1

value=$(sshd -T 2>/dev/null | awk '/^maxstartups/ {print $2}')

if [[ "$value" =~ ^[0-9]+:[0-9]+:[0-9]+$ ]]; then
    IFS=':' read -r start rate full <<< "$value"

    if (( start > 10 || rate > 30 || full > 60 )); then
        flag=0
    fi
else
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
