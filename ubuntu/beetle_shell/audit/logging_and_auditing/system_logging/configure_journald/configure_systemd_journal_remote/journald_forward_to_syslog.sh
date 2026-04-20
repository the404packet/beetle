#!/usr/bin/env bash
NAME="ensure journald ForwardToSyslog is disabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

analyze_cmd="$(readlink -f /bin/systemd-analyze)"
actual=$("$analyze_cmd" cat-config systemd/journald.conf 2>/dev/null \
         | grep -Ps "^\s*ForwardToSyslog\s*=" | tail -1 \
         | awk -F= '{print $2}' | tr -d ' ')

[ "$actual" = "no" ] && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0