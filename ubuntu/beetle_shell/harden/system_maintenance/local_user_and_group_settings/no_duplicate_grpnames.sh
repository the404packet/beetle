#!/usr/bin/env bash

NAME="verify no duplicate group names exist"

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
    echo -e "  1. Rename duplicate group: groupmod -n <new_groupname> <old_groupname>"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

# Iterate unique duplicate names (one entry per duplicated name, not per line)
while read -r l_count l_group; do
    if [ "$l_count" -gt 1 ]; then
        # Line numbers of every occurrence of this name
        mapfile -t line_nums < <(awk -F: -v n="$l_group" '$1 == n {print NR}' "$FILE")

        # Skip the first occurrence; rename the rest by editing the file directly.
        # Using sed on the specific line avoids groupmod's ambiguous name-lookup
        # behaviour when multiple entries share the same name.
        idx=0
        for lineno in "${line_nums[@]:1}"; do
            idx=$(( idx + 1 ))
            new_groupname="${l_group}_${idx}"
            while getent group "$new_groupname" &>/dev/null; do
                new_groupname="${new_groupname}_${idx}"
            done
            if sed -i "${lineno}s/^[^:]*:/${new_groupname}:/" "$FILE"; then
                echo -e "  ${GREEN}Renamed duplicate group '$l_group' (line $lineno) to '$new_groupname'${RESET}"
            else
                echo -e "  ${RED}Failed to rename duplicate group '$l_group' at line $lineno${RESET}"
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