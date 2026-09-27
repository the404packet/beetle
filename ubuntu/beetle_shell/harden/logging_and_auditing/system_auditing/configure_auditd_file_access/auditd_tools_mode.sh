#!/usr/bin/env bash
NAME="ensure audit tools mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

count="$AC_tools_count"
for ((i=0; i<count; i++)); do
    t_var="AC_tool_${i}"; tool="${!t_var}"
    [ -f "$tool" ] && chmod go-w "$tool" 2>/dev/null
done

fail=0
for ((i=0; i<count; i++)); do
    t_var="AC_tool_${i}"; tool="${!t_var}"
    [ -f "$tool" ] || continue
    mode=$(stat -Lc '%#a' "$tool")
    [ $(( 8#$mode & 8#$AC_tools_perm_mask )) -gt 0 ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0