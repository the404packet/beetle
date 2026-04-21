#!/usr/bin/env bash

NAME='ensure libpam-modules is installed'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_VERSION="${PAM_LIBPAM_MODULES_MIN_VERSION:-1.5.3-5}"

if ! is_package_installed "libpam-modules"; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

installed=$(get_installed_version "libpam-modules")

if [ -z "$installed" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

if printf '%s\n%s' "$MIN_VERSION" "$installed" | sort -V | head -1 | grep -qx "$MIN_VERSION"; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
