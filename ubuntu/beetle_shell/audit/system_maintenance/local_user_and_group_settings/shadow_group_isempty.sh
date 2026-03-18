#!/usr/bin/env bash

NAME="verify shadow group has no members or primary users"
SEVERITY="basic"

GROUP_FILE="/etc/group"
PASSWD_FILE="/etc/passwd"

# Files must exist
[ -f "$GROUP_FILE" ] || exit 2
[ -f "$PASSWD_FILE" ] || exit 2

shadow_gid=$(getent group shadow | awk -F: '{print $3}')

# If shadow group does not exist, treat as pass
[ -z "$shadow_gid" ] && {
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
}

output=$(
{
 # Check shadow group members
 awk -F: '($1=="shadow" && $NF!="") {print " - shadow group has members: " $NF}' "$GROUP_FILE"

 # Check users with shadow as primary group
 awk -F: '($4 == '"$shadow_gid"') {print " - user: \"" $1 "\" primary group is the shadow group"}' "$PASSWD_FILE"
}
)

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
