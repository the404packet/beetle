#!/usr/bin/env bash
NAME="ensure systemd-journal-remote service is not in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

systemctl stop "$JR_remote_sock" "$JR_remote_svc" 2>/dev/null
systemctl mask "$JR_remote_sock" "$JR_remote_svc" 2>/dev/null

fail=0
for unit in "$JR_remote_sock" "$JR_remote_svc"; do
    enabled=$(systemctl is-enabled "$unit" 2>/dev/null)
    active=$(systemctl  is-active  "$unit" 2>/dev/null)
    [ "$active"  = "active"  ] && { fail=1; }
    [ "$enabled" = "enabled" ] && { fail=1; }
done

[ "$fail" -eq 0 ] && echo -e "${GREEN}SUCCESS${RESET}" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0