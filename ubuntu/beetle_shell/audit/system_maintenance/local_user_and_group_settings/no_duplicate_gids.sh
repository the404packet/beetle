#!/usr/bin/env bash

NAME="verify no duplicate GIDs exist"
SEVERITY="basic"

FILE="/etc/group"

# File must exist
[ -f "$FILE" ] || exit 2

output=$(
{
 while read -r l_count l_gid; do
  if [ "$l_count" -gt 1 ]; then
   echo -e "Duplicate GID: \"$l_gid\" Groups: \"$(awk -F: '($3 == n) {print $1}' n=$l_gid "$FILE" | xargs)\""
  fi
 done < <(cut -f3 -d":" "$FILE" | sort -n | uniq -c)
}
)

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
