#!/usr/bin/env bash
NAME="ensure journald service is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

svc="$LJ_service"
enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
active=$(systemctl is-active "$svc" 2>/dev/null)

[ "$enabled" != "static" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
[ "$active"  != "active" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

echo -e "${GREEN}HARDENED${RESET}"; exit 0