#!/usr/bin/env bash

NAME="ensure password quality is enforced for the root user"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

CONF_DIR="/etc/security/pwquality.conf.d"
CONF_FILE="${CONF_DIR}/50-pwroot.conf"

[ ! -d "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

if ! grep -Psi -- "^\h*enforce_for_root\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    printf '\n%s\n' "enforce_for_root" > "$CONF_FILE"
fi

if grep -Psi -- "^\h*enforce_for_root\b" \
   /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q .; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
