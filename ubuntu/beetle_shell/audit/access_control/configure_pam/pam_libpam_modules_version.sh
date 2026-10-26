#!/usr/bin/env bash

NAME="ensure libpam-modules is installed"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_VERSION="${PAM_LIBPAM_MODULES_MIN_VERSION:-1.5.3-5}"

if is_package_installed "libpam-modules"; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
