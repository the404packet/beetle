#!/usr/bin/env bash
NAME="ensure XDMCP is not enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

count="$GD_xdmcp_count"
for ((i=0; i<count; i++)); do
    f_var="GD_xdmcp_${i}"; f="${!f_var}"
    [ -f "$f" ] || continue
    # comment out Enable=true inside [xdmcp] block
    awk '/\[xdmcp\]/{f=1} /\[/{if(!/\[xdmcp\]/)f=0} f && /^\s*Enable\s*=\s*true/{sub(/Enable/,"#Enable")} {print}' \
        "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
done

fail=0
for ((i=0; i<count; i++)); do
    f_var="GD_xdmcp_${i}"; f="${!f_var}"
    [ -f "$f" ] || continue
    result=$(awk '/\[xdmcp\]/{f=1;next} /\[/{f=0} f && /^\s*Enable\s*=\s*true/' "$f")
    [ -n "$result" ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0