#!/usr/bin/env bash
NAME="ensure journald service is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

svc="$LJ_service"
systemctl unmask "$svc" 2>/dev/null
systemctl start  "$svc" 2>/dev/null

active=$(systemctl is-active "$svc" 2>/dev/null)
[ "$active" != "active" ] && { echo "  FAIL: could not start $svc"; echo -e "${RED}FAILED${RESET}"; exit 1; }

echo -e "${GREEN}SUCCESS${RESET}"; exit 0