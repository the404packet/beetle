#!/usr/bin/env bash
NAME="ensure the running and on disk configuration is the same"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
require_present pkg auditd

result=$(augenrules --check 2>/dev/null)

echo "$result" | grep -q "No change" \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0