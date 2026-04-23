#!/usr/bin/env bash
NAME='ensure bootloader password is set'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

flag=1
grep -Pq '^\s*set superusers=' "$BL_grub_cfg" 2>/dev/null || flag=0
awk -F. '/^\s*password/ {print $1"."$2"."$3}' "$BL_grub_cfg" 2>/dev/null \
    | grep -Pq 'password_pbkdf2\s+\S+\s+grub\.pbkdf2\.sha512' || flag=0

(( flag )) && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0