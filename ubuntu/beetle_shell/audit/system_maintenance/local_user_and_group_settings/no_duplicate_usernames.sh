#!/usr/bin/env bash

NAME="verify no duplicate user names exist"
SEVERITY="basic"

PASSWD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"

# Files must exist
[ -f "$PASSWD_FILE" ] || exit 2
[ -f "$GROUP_FILE" ] || exit 2

output=$(
{
 while read -r l_count l_user; do
  if [ "$l_count" -gt 1 ]; then
   echo -e "Duplicate User: \"$l_user\" Users: \"$(awk -F: '($1 == n) {print $1}' n=$l_user "$PASSWD_FILE" | xargs)\""
  fi
 done < <(cut -f1 -d":" "$GROUP_FILE" | sort | uniq -c)
}
)

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
