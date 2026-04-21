#!/usr/bin/env bash
NAME="ensure the running and on disk configuration is the same"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

result=$(augenrules --check 2>/dev/null)

echo "$result" | grep -q "No change" \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0