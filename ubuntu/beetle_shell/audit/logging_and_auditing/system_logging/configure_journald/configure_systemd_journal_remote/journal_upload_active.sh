#!/usr/bin/env bash
NAME="ensure systemd-journal-upload is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

svc="$JR_upload_svc"
enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
active=$(systemctl  is-active  "$svc" 2>/dev/null)

[ "$enabled" != "enabled" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
[ "$active"  != "active"  ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

echo -e "${GREEN}HARDENED${RESET}"; exit 0