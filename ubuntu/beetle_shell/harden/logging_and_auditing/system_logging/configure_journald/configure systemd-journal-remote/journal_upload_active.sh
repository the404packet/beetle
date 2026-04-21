#!/usr/bin/env bash
NAME="ensure systemd-journal-upload is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

svc="$JR_upload_svc"
systemctl unmask    "$svc" 2>/dev/null
systemctl --now enable "$svc" 2>/dev/null \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }

active=$(systemctl is-active "$svc" 2>/dev/null)
[ "$active" != "active" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

echo -e "${GREEN}SUCCESS${RESET}"; exit 0