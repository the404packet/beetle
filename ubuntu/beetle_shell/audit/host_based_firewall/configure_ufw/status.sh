#!/usr/bin/env bash

NAME='ufw firewall state'
SEVERITY="basic"

flag=1

# service enabled
if ! systemctl is-enabled ufw.service >/dev/null 2>&1; then
    flag=0
fi

# service active
if ! systemctl is-active ufw.service >/dev/null 2>&1; then
    flag=0
fi

# firewall active
if ! ufw status | grep -q "Status: active"; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
