#!/usr/bin/env bash

NAME='ensure pam_unix module is enabled'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1

for context in account session auth password; do
    if ! grep -P -- '\bpam_unix\.so\b' /etc/pam.d/common-${context} 2>/dev/null | grep -q .; then
        flag=0
        break
    fi
done

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
