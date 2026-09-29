#!/usr/bin/env bash
NAME="ensure audit_backlog_limit is sufficient"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
require_present pkg auditd
require_present file /etc/default/grub

param_name="AD_grub_1_name"; name="${!param_name}"
[ -z "$name" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

result=$(find /boot -xdev -maxdepth 3 -type f -name 'grub.cfg' \
         -exec grep -Ph -- '^\h*linux' {} + 2>/dev/null \
         | grep -Pv "${name}=\d+\b")

[ -z "$result" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
