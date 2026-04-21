#!/usr/bin/env bash

NAME='ensure sudo commands use pty'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "sudo" && ! is_package_installed "sudo-ldap"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

flag=1

# use_pty must be set
if ! grep -rPi -- '^\h*Defaults\h+([^#\n\r]+,\h*)?use_pty\b' /etc/sudoers* 2>/dev/null | grep -q .; then
    flag=0
fi

# !use_pty must not be set
if grep -rPi -- '^\h*Defaults\h+([^#\n\r]+,\h*)?!use_pty\b' /etc/sudoers* 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0