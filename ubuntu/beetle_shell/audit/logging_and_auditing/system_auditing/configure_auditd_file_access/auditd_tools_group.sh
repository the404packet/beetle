#!/usr/bin/env bash
NAME="ensure audit tools group owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
count="$AC_tools_count"
for ((i=0; i<count; i++)); do
    t_var="AC_tool_${i}"; tool="${!t_var}"
    [ -f "$tool" ] || continue
    grp=$(stat -Lc '%G' "$tool")
    [ "$grp" != "root" ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0