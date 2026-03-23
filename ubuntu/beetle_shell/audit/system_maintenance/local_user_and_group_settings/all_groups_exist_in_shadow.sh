#!/usr/bin/env bash

NAME=" all passwd GIDs exist in group"
SEVERITY="basic"

PASSWD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"

# Files must exist
[ -f "$PASSWD_FILE" ] || exit 2
[ -f "$GROUP_FILE" ] || exit 2

output=$(
{
 a_passwd_group_gid=("$(awk -F: '{print $4}' "$PASSWD_FILE" | sort -u)")
 a_group_gid=("$(awk -F: '{print $3}' "$GROUP_FILE" | sort -u)")
 a_passwd_group_diff=("$(printf '%s\n' "${a_group_gid[@]}" \
"${a_passwd_group_gid[@]}" | sort | uniq -u)")

 while IFS= read -r l_gid; do
  awk -F: '($4 == '"$l_gid"') {print " - User: \"" $1 "\" has GID: \"" $4 "\" which does not exist in /etc/group"}' "$PASSWD_FILE"
 done < <(printf '%s\n' "${a_passwd_group_gid[@]}" \
"${a_passwd_group_diff[@]}" | sort | uniq -D | uniq)

 unset a_passwd_group_gid
 unset a_group_gid
 unset a_passwd_group_diff
}
)

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
