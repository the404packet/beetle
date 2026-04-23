#!/usr/bin/env bash
NAME="ensure XDMCP is not enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
gdm_installed || { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

fail=0
count="$GD_xdmcp_count"
for ((i=0; i<count; i++)); do
    f_var="GD_xdmcp_${i}"; f="${!f_var}"
    [ -f "$f" ] || continue
    result=$(awk '/\[xdmcp\]/{f=1;next} /\[/{f=0} f && /^\s*Enable\s*=\s*true/' "$f")
    [ -n "$result" ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0