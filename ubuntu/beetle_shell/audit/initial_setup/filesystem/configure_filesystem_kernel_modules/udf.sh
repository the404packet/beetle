#!/usr/bin/env bash
NAME="ensure udf kernel module is not available"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

beetle_module_audit "udf" "fs" \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0