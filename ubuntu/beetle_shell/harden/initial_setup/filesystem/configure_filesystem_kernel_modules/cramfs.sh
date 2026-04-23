#!/usr/bin/env bash
NAME="ensure cramfs kernel module is not available"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

beetle_module_harden "cramfs" "fs" "$FM_modprobe_dir"
beetle_module_audit "cramfs" "fs" \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0