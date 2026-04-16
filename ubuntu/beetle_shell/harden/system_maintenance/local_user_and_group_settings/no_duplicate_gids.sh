#!/usr/bin/env bash

NAME="verify no duplicate GIDs exist"
SEVERITY="basic"

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
echo -e "Press ${GREEN}ENTER${RESET} to apply default hardening, or type ${RED}no${RESET} to configure manually: "

read -r response </dev/tty

if [[ "${response,,}" == "no" ]]; then
    echo -e "${YELLOW}Manual remediation required. No changes made.${RESET}"
    echo -e "  1. Assign new unique GID: groupmod -g <new_gid> <groupname>"
    echo -e "  2. Fix file ownership:    find / -group <old_gid> -exec chgrp <new_gid> {} \;"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

while read -r l_count l_gid; do
    if [ "$l_count" -gt 1 ]; then
        groups=($(awk -F: '($3 == n) {print $1}' n=$l_gid "$FILE"))
        # Keep first group, reassign rest
        for i in "${!groups[@]}"; do
            if [ "$i" -eq 0 ]; then
                continue
            fi
            grp="${groups[$i]}"
            # Find next available GID above 1000
            new_gid=$(awk -F: '{print $3}' "$FILE" | sort -n | awk 'BEGIN{gid=1000} $1==gid{gid++} END{print gid}')
            groupmod -g "$new_gid" "$grp" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}Reassigned GID of '$grp' from $l_gid to $new_gid${RESET}"
                # Fix file ownership
                find / -xdev -group "$l_gid" 2>/dev/null | xargs chgrp "$new_gid" 2>/dev/null
            else
                echo -e "  ${RED}Failed to reassign GID for '$grp'${RESET}"
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