#!/usr/bin/env bash

NAME="verify no duplicate group names exist"
SEVERITY="basic"

FILE="/etc/group"

# File must exist
[ -f "$FILE" ] || exit 2

output=$(
{
 while read -r l_count l_group; do
  if [ "$l_count" -gt 1 ]; then
   echo -e "Duplicate Group: \"$l_group\" Groups: \"$(awk -F: '($1 == n) {print $1}' n=$l_group "$FILE" | xargs)\""
  fi
 done < <(cut -f1 -d":" "$FILE" | sort | uniq -c)
}
)

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
