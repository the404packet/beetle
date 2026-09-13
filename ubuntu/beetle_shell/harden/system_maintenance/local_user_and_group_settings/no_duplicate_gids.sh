#!/usr/bin/env bash

NAME="verify no duplicate GIDs exist"

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/group"

[ -f "$FILE" ] || exit 2

duplicates=$(
    while read -r l_count l_gid; do
        if [ "$l_count" -gt 1 ]; then
            groups=$(awk -F: '($3 == n) {print $1}' n=$l_gid "$FILE" | xargs)
            echo "  - GID: '$l_gid' is shared by groups: '$groups'"
        fi
    done < <(cut -f3 -d":" "$FILE" | sort -n | uniq -c)
)

if [[ -z "$duplicates" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${YELLOW}Duplicate GIDs found:${RESET}"
echo "$duplicates"
echo
echo -e "${YELLOW}Default hardening: Assign a new unique GID to duplicate groups and fix file ownership.${RESET}"

response="y"
if [ -t 0 ] && [ -c /dev/tty ]; then
    while true; do
        echo -e "Apply default hardening? [${GREEN}y${RESET}/${RED}n${RESET}] (default: y): "
        read -r response </dev/tty
        response="${response:-y}"
        case "${response,,}" in
            y|yes) response="y"; break ;;
            n|no)  response="n"; break ;;
            *) echo -e "${RED}Please answer y or n.${RESET}" ;;
        esac
    done
fi

if [[ "$response" == "n" ]]; then
    echo -e "${YELLOW}Manual remediation required. No changes made.${RESET}"
    echo -e "  1. Assign new unique GID: groupmod -g <new_gid> <groupname>"
    echo -e "  2. Fix file ownership:    find / -group <old_gid> -exec chgrp <new_gid> {} \;"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

# Find the first free GID above 1000.
# Stop as soon as gid falls into a gap (doesn't match an existing GID).
next_gid=$(
    awk -F: '{print $3}' "$FILE" | sort -n -u | awk '
        BEGIN { gid = 1000 }
        $1 == gid { gid++; next }
        $1 > gid  { exit }
        END       { print gid }
    '
)
[ -z "$next_gid" ] && next_gid=1000

while read -r l_count l_gid; do
    if [ "$l_count" -gt 1 ]; then
        groups=($(awk -F: '($3 == n) {print $1}' n=$l_gid "$FILE"))
        for i in "${!groups[@]}"; do
            if [ "$i" -eq 0 ]; then
                continue
            fi
            grp="${groups[$i]}"

            # Guard: ensure next_gid is not already taken (belt-and-braces).
            while awk -F: -v G="$next_gid" '$3 == G {found=1; exit} END {exit !found}' "$FILE"; do
                next_gid=$(( next_gid + 1 ))
            done

            new_gid="$next_gid"
            if groupmod -g "$new_gid" "$grp" 2>/dev/null; then
                echo -e "  ${GREEN}Reassigned GID of '$grp' from $l_gid to $new_gid${RESET}"
                find / -xdev -group "$l_gid" -print0 2>/dev/null | xargs -0 chgrp "$new_gid" 2>/dev/null
                next_gid=$(( next_gid + 1 ))
            else
                echo -e "  ${RED}Failed to reassign GID for '$grp' (target GID $new_gid)${RESET}"
                FAILED=1
            fi
        done
    fi
done < <(cut -f3 -d":" "$FILE" | sort -n | uniq -c)

if [[ "$FAILED" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0