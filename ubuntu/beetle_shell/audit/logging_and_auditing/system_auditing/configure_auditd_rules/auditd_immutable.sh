#!/usr/bin/env bash
NAME="ensure the audit configuration is immutable"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

result=$(grep -Ph -- '^\s*-e\s+2\b' "$AR_rules_dir"/*.rules 2>/dev/null | tail -1)

[ -n "$result" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0