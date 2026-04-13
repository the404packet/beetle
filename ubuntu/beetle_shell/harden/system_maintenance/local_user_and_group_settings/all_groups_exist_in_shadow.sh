#!/usr/bin/env bash

NAME=" all passwd GIDs exist in group"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

PASSWD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"

[ -f "$PASSWD_FILE" ] || exit 2
[ -f "$GROUP_FILE" ] || exit 2

a_passwd_group_gid=("$(awk -F: '{print $4}' "$PASSWD_FILE" | sort -u)")
a_group_gid=("$(awk -F: '{print $3}' "$GROUP_FILE" | sort -u)")
a_passwd_group_diff=("$(printf '%s\n' "${a_group_gid[@]}" \
"${a_passwd_group_gid[@]}" | sort | uniq -u)")

missing_users=$(
    while IFS= read -r l_gid; do
        awk -F: '($4 == '"$l_gid"') {print $1 ":" $4}' "$PASSWD_FILE"
    done < <(printf '%s\n' "${a_passwd_group_gid[@]}" \
    "${a_passwd_group_diff[@]}" | sort | uniq -D | uniq)
)

if [[ -z "$missing_users" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

# Show what was found
echo -e "${YELLOW}The following users have GIDs that do not exist in /etc/group:${RESET}"
while IFS=: read -r username gid; do
    echo "  - User: '$username' has GID: '$gid' which does not exist in /etc/group"
done <<< "$missing_users"

echo
echo -e "${YELLOW}Default hardening (Option 1): Create missing groups with the corresponding GID.${RESET}"
echo -e "Press ${GREEN}ENTER${RESET} to apply default hardening, or type ${RED}no${RESET} to configure manually: "

# Read from terminal directly in case stdout is redirected
read -r response </dev/tty

if [[ "${response,,}" == "no" ]]; then
    echo -e "${YELLOW}Manual remediation required. No changes made.${RESET}"
    echo -e "For each affected user, either:"
    echo -e "  1. Create the missing group:  groupadd -g <GID> <groupname>"
    echo -e "  2. Change the user's GID:     usermod -g <existing_GID> <username>"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

# Apply default hardening — Option 1: create missing groups
FAILED=0

while IFS=: read -r username gid; do
    if ! getent group "$gid" &>/dev/null; then
        groupadd -g "$gid" "group_${gid}" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "  ${GREEN}Created group 'group_${gid}' with GID $gid for user '$username'${RESET}"
        else
            echo -e "  ${RED}Failed to create group for GID $gid (user: '$username')${RESET}"
            FAILED=1
        fi
    fi
done <<< "$missing_users"

if [[ "$FAILED" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0