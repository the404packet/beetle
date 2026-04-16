#!/usr/bin/env bash

NAME="verify no duplicate group names exist"
SEVERITY="basic"

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/group"

[ -f "$FILE" ] || exit 2

duplicates=$(
    while read -r l_count l_group; do
        if [ "$l_count" -gt 1 ]; then
            echo "  - Duplicate group name: '$l_group'"
        fi
    done < <(cut -f1 -d":" "$FILE" | sort | uniq -c)
)

if [[ -z "$duplicates" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${YELLOW}Duplicate group names found:${RESET}"
echo "$duplicates"
echo
echo -e "${YELLOW}Default hardening: Append a numeric suffix to duplicate group names to make them unique.${RESET}"
echo -e "Press ${GREEN}ENTER${RESET} to apply default hardening, or type ${RED}no${RESET} to configure manually: "

read -r response </dev/tty

if [[ "${response,,}" == "no" ]]; then
    echo -e "${YELLOW}Manual remediation required. No changes made.${RESET}"
    echo -e "  1. Rename duplicate group: groupmod -n <new_groupname> <old_groupname>"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

while read -r l_count l_group; do
    if [ "$l_count" -gt 1 ];
    then
        occurrences=($(awk -F: '($1 == n) {print NR}' n=$l_group "$FILE"))
        # Skip first occurrence, rename the rest
        for i in "${!occurrences[@]}"; do
            if [ "$i" -eq 0 ]; then
                continue
            fi
            new_groupname="${l_group}_${i}"
            # Make sure new group name does not already exist
            while getent group "$new_groupname" &>/dev/null; do
                new_groupname="${new_groupname}_${i}"
            done
            groupmod -n "$new_groupname" "$l_group" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}Renamed duplicate group '$l_group' to '$new_groupname'${RESET}"
            else
                echo -e "  ${RED}Failed to rename duplicate group '$l_group'${RESET}"
                FAILED=1
            fi
        done
    fi
done < <(cut -f1 -d":" "$FILE" | sort | uniq -c)

if [[ "$FAILED" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0