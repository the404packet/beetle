#!/usr/bin/env bash
NAME="ensure systemd-journal-upload is enabled and active"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' "$JR_package" 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q "$JR_package" </dev/null >/dev/null 2>&1 || true
fi

svc="$JR_upload_svc"
[ -z "$svc" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

systemctl unmask  "$svc" 2>/dev/null || true
systemctl enable  "$svc" 2>/dev/null || true
systemctl start   "$svc" 2>/dev/null || true

active=$(systemctl is-active "$svc" 2>/dev/null)
[ "$active" != "active" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

echo -e "${GREEN}SUCCESS${RESET}"; exit 0
