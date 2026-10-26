#!/usr/bin/env bash
NAME="ensure systemd-journal-upload is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
require_present pkg systemd-journal-remote

svc="$JR_upload_svc"
[ -z "$svc" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
active=$(systemctl  is-active  "$svc" 2>/dev/null)

[[ "$enabled" == "enabled" || "$enabled" == "enabled-runtime" ]] || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
[ "$active" != "active" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

echo -e "${GREEN}HARDENED${RESET}"; exit 0
