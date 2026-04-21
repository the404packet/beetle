#!/usr/bin/env bash

NAME="verify no duplicate UIDs exist"
SEVERITY="basic"

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

FILE="/etc/passwd"

[ -f "$FILE" ] || exit 2

duplicates=$(
    while read -r l_count l_uid; do
        if [ "$l_count" -gt 1 ]; then
            users=$(awk -F: '($3 == n) {print $1}' n=$l_uid "$FILE" | xargs)
            echo "  - UID: '$l_uid' is shared by users: '$users'"
        fi
    done < <(cut -f3 -d":" "$FILE" | sort -n | uniq -c)
)

if [[ -z "$duplicates" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo -e "${YELLOW}Duplicate UIDs found:${RESET}"
echo "$duplicates"
echo
echo -e "${YELLOW}Default hardening: Assign a new unique UID to duplicate users and fix file ownership.${RESET}"
echo -e "Press ${GREEN}ENTER${RESET} to apply default hardening, or type ${RED}no${RESET} to configure manually: "

read -r response </dev/tty

if [[ "${response,,}" == "no" ]]; then
    echo -e "${YELLOW}Manual remediation required. No changes made.${RESET}"
    echo -e "  1. Assign new unique UID: usermod -u <new_uid> <username>"
    echo -e "  2. Fix file ownership:    find / -user <old_uid> -exec chown <new_uid> {} \;"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

while read -r l_count l_uid; do
    if [ "$l_count" -gt 1 ]; then
        users=($(awk -F: '($3 == n) {print $1}' n=$l_uid "$FILE"))
        # Keep first user, reassign rest
        for i in "${!users[@]}"; do
            if [ "$i" -eq 0 ]; then
                continue
            fi
            user="${users[$i]}"
            # Find next available UID above 1000
            new_uid=$(awk -F: '{print $3}' "$FILE" | sort -n | awk 'BEGIN{uid=1000} $1==uid{uid++} END{print uid}')
            usermod -u "$new_uid" "$user" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}Reassigned UID of '$user' from $l_uid to $new_uid${RESET}"
                # Fix file ownership
                find / -xdev -nouser -o -user "$l_uid" 2>/dev/null | xargs chown "$new_uid" 2>/dev/null
            else
                echo -e "  ${RED}Failed to reassign UID for '$user'${RESET}"
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