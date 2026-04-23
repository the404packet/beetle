#!/usr/bin/env bash
NAME="ensure SUID and SGID files are reviewed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
count="$SS_count"

for ((i=0; i<count; i++)); do
    p_var="SS_${i}_path"; path="${!p_var}"
    [ -f "$path" ] || continue

    mode=$(stat -Lc '%a' "$path" 2>/dev/null)
    [ -z "$mode" ] && continue

    perm=$((8#$mode))
    has_suid=$(( perm & 04000 ))
    has_sgid=$(( perm & 02000 ))

    [ "$has_suid" -eq 0 ] && [ "$has_sgid" -eq 0 ] && continue

    # file has suid/sgid — check if dpkg expects it
    pkg=$(dpkg -S "$path" 2>/dev/null | awk -F: '{print $1}' | head -1)
    if [ -n "$pkg" ]; then
        # get expected mode from dpkg statoverride or verify via original permissions
        expected_mode=$(dpkg-statoverride --list "$path" 2>/dev/null | awk '{print $3}')
        if [ -n "$expected_mode" ]; then
            expected_perm=$((8#$expected_mode))
            expected_suid=$(( expected_perm & 04000 ))
            expected_sgid=$(( expected_perm & 02000 ))
            # suid/sgid present but not expected
            [ "$has_suid" -gt 0 ] && [ "$expected_suid" -eq 0 ] && { fail=1; break; }
            [ "$has_sgid" -gt 0 ] && [ "$expected_sgid" -eq 0 ] && { fail=1; break; }
        else
            # no statoverride entry — check against known risky list
            # if it's in our known_risky list and has suid/sgid, flag it
            fail=1; break
        fi
    else
        # not from any package — flag it
        fail=1; break
    fi
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0