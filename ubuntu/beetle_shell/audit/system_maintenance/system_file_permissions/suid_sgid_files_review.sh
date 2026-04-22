#!/usr/bin/env bash
NAME="ensure SUID and SGID files are reviewed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
count="$SS_count"

for ((i=0; i<count; i++)); do
    p_var="SS_${i}_path"; path="${!p_var}"
    [ -f "$path" ] || continue

    mode=$(stat -Lc '%#a' "$path" 2>/dev/null)
    has_suid=$(( 8#$mode & 04000 ))
    has_sgid=$(( 8#$mode & 02000 ))
    [ "$has_suid" -eq 0 ] && [ "$has_sgid" -eq 0 ] && continue

    # verify checksum via dpkg
    pkg=$(dpkg -S "$path" 2>/dev/null | awk -F: '{print $1}' | head -1)
    if [ -n "$pkg" ]; then
        dpkg --verify "$pkg" 2>/dev/null | grep -q "^??5.*${path}" && { fail=1; break; }
    else
        # not from any package — suspicious
        fail=1; break
    fi
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0