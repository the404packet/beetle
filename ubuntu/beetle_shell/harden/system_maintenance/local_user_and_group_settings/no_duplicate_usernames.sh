#!/usr/bin/env bash

NAME="verify no duplicate user names exist"

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

PASSWD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"

[ -f "$PASSWD_FILE" ] || exit 2
[ -f "$GROUP_FILE" ] || exit 2

duplicates=$(
    while read -r l_count l_user; do
        if [ "$l_count" -gt 1 ]; then
            echo "  - Duplicate username: '$l_user'"
        fi
    done < <(cut -f1 -d":" "$PASSWD_FILE" | sort | uniq -c)
)

if [[ -z "$duplicates" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${YELLOW}Duplicate usernames found:${RESET}"
echo "$duplicates"
echo
echo -e "${YELLOW}Default hardening: Append a numeric suffix to duplicate usernames to make them unique.${RESET}"

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
    echo -e "  1. Rename duplicate user: usermod -l <new_username> <old_username>"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

while read -r l_count l_user; do
    if [ "$l_count" -gt 1 ]; then
        mapfile -t line_nums < <(awk -F: -v n="$l_user" '$1 == n {print NR}' "$PASSWD_FILE")

        # Skip the first occurrence; rename the rest by editing the file directly.
        # usermod -l operates on the first name match, which after a rename is
        # no longer the entry we intended to change.
        idx=0
        for lineno in "${line_nums[@]:1}"; do
            idx=$(( idx + 1 ))
            new_username="${l_user}_${idx}"
            while getent passwd "$new_username" &>/dev/null; do
                new_username="${new_username}_${idx}"
            done
            if sed -i "${lineno}s/^[^:]*:/${new_username}:/" "$PASSWD_FILE"; then
                echo -e "  ${GREEN}Renamed duplicate user '$l_user' (line $lineno) to '$new_username'${RESET}"
            else
                echo -e "  ${RED}Failed to rename duplicate user '$l_user' at line $lineno${RESET}"
                FAILED=1
            fi
        done
    fi
done < <(cut -f1 -d":" "$PASSWD_FILE" | sort | uniq -c)

if [[ "$FAILED" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0