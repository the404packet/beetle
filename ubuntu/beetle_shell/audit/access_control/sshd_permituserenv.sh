#!/usr/bin/env bash

NAME='sshd PermitUserEnvironment config'
SEVERITY="basic"

flag=1

value=$(sshd -T 2>/dev/null | awk '/^permituserenvironment/ {print $2}')

if [[ "$value" != "no" ]]; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
