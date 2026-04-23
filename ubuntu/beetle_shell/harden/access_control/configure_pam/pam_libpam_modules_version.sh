#!/usr/bin/env bash

NAME='ensure libpam-modules is installed'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MIN_VERSION="${PAM_LIBPAM_MODULES_MIN_VERSION:-1.5.3-5}"

installed=$(get_installed_version "libpam-modules")

if printf '%s\n%s' "$MIN_VERSION" "$installed" | sort -V | head -1 | grep -qx "$MIN_VERSION"; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

if apt-get upgrade -y libpam-modules 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
