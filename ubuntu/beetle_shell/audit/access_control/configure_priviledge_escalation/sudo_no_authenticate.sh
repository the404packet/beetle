#!/usr/bin/env bash

NAME="ensure re-authentication for privilege escalation is not disabled globally"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

if grep -r "^[^#].*\!authenticate" /etc/sudoers* 2>/dev/null | grep -q .; then
    echo -e "${RED}NOT HARDENED${RESET}"
else
    echo -e "${GREEN}HARDENED${RESET}"
fi

exit 0