#!/usr/bin/env bash
NAME="ensure journald log file rotation is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

analyze_cmd="$(readlink -f /bin/systemd-analyze)"
conf="systemd/journald.conf"
fail=0
count="$LJ_rot_count"

for ((i=0; i<count; i++)); do
    key_var="LJ_rot_${i}_key"; key="${!key_var}"
    # search effective config via systemd-analyze cat-config
    found=$(  "$analyze_cmd" cat-config "$conf" 2>/dev/null \
            | grep -Ps "^\s*${key}\s*=\s*.+" | tail -1)
    if [ -z "$found" ]; then
        fail=1
    fi
done

[ "$fail" -eq 0 ] && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0