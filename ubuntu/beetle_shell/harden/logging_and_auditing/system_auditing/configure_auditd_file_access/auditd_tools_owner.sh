#!/usr/bin/env bash
NAME="ensure audit tools owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

count="$AC_tools_count"
for ((i=0; i<count; i++)); do
    t_var="AC_tool_${i}"; tool="${!t_var}"
    [ -f "$tool" ] && chown root "$tool" 2>/dev/null
done

fail=0
for ((i=0; i<count; i++)); do
    t_var="AC_tool_${i}"; tool="${!t_var}"
    [ -f "$tool" ] || continue
    owner=$(stat -Lc '%U' "$tool")
    [ "$owner" != "root" ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0