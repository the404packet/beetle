#!/usr/bin/env bash

NAME="verify no duplicate user names exist"
SEVERITY="basic"

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
echo -e "Press ${GREEN}ENTER${RESET} to apply default hardening, or type ${RED}no${RESET} to configure manually: "

read -r response </dev/tty

if [[ "${response,,}" == "no" ]]; then
    echo -e "${YELLOW}Manual remediation required. No changes made.${RESET}"
    echo -e "  1. Rename duplicate user: usermod -l <new_username> <old_username>"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

while read -r l_count l_user; do
    if [ "$l_count" -gt 1 ]; then
        # Get all lines with this username
        occurrences=($(awk -F: '($1 == n) {print NR}' n=$l_user "$PASSWD_FILE"))
        # Skip first occurrence, rename the rest
        for i in "${!occurrences[@]}"; do
            if [ "$i" -eq 0 ]; then
                continue
            fi
            new_username="${l_user}_${i}"
            # Make sure new username does not already exist
            while getent passwd "$new_username" &>/dev/null; do
                new_username="${new_username}_${i}"
            done
            usermod -l "$new_username" "$l_user" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}Renamed duplicate user '$l_user' to '$new_username'${RESET}"
            else
                echo -e "  ${RED}Failed to rename duplicate user '$l_user'${RESET}"
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