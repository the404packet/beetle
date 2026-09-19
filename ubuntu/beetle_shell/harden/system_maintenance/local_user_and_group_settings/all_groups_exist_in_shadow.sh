#!/usr/bin/env bash

NAME="all passwd GIDs exist in group"

GREEN="\e[32m"
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
    echo -e "For each affected user, either:"
    echo -e "  1. Create the missing group:  groupadd -g <GID> <groupname>"
    echo -e "  2. Change the user's GID:     usermod -g <existing_GID> <username>"
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

# Apply default hardening — Option 1: create missing groups
FAILED=0

while IFS=: read -r username gid; do
    # CHANGED: use numeric GID lookup, not name lookup.
    # `getent group "$gid"` looks up by *name*, which fails for a numeric
    # string. The correct check is whether the GID appears in field 3.
    if ! awk -F: -v g="$gid" '$3 == g {found=1; exit} END {exit !found}' "$GROUP_FILE"; then
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