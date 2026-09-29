#!/usr/bin/env bash

NAME="verify no duplicate UIDs exist"

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

# Interactive prompt only when we have a terminal; otherwise default to "y"
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
    echo -e "  1. Assign new unique UID: usermod -u <new_uid> <username>"
    echo -e "  2. Fix file ownership:    find / -user <old_uid> -exec chown <new_uid> {} \;"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

FAILED=0

# Find the first free UID above 1000.
# Stop as soon as uid falls into a gap (doesn't match an existing UID).
next_uid=$(
    awk -F: '{print $3}' "$FILE" | sort -n -u | awk '
        BEGIN { uid = 1000 }
        $1 == uid { uid++; next }
        $1 > uid  { exit }
        END       { print uid }
    '
)
[ -z "$next_uid" ] && next_uid=1000

while read -r l_count l_uid; do
    if [ "$l_count" -gt 1 ]; then
        users=($(awk -F: '($3 == n) {print $1}' n=$l_uid "$FILE"))
        # Keep first user, reassign rest
        for i in "${!users[@]}"; do
            if [ "$i" -eq 0 ]; then
                continue
            fi
            user="${users[$i]}"

            # Guard: ensure next_uid is not already taken.
            while awk -F: -v U="$next_uid" '$3 == U {found=1; exit} END {exit !found}' "$FILE"; do
                next_uid=$(( next_uid + 1 ))
            done

            new_uid="$next_uid"
            if usermod -u "$new_uid" "$user" 2>/dev/null; then
                echo -e "  ${GREEN}Reassigned UID of '$user' from $l_uid to $new_uid${RESET}"
                # Re-own files that still carry the old numeric UID
                find / -xdev -user "$l_uid" -print0 2>/dev/null | xargs -0 chown "$new_uid" 2>/dev/null
                next_uid=$(( next_uid + 1 ))
            else
                echo -e "  ${RED}Failed to reassign UID for '$user' (target UID $new_uid)${RESET}"
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