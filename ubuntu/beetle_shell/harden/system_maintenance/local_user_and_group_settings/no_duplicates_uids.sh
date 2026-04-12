#!/usr/bin/env bash

NAME="verify no duplicate UIDs exist"
SEVERITY="basic"

FILE="/etc/passwd"

# File must exist
[ -f "$FILE" ] || exit 2

output=$(
{
 while read -r l_count l_uid; do
  if [ "$l_count" -gt 1 ]; then
   echo -e "Duplicate UID: \"$l_uid\" Users: \"$(awk -F: '($3 == n) {print $1}' n=$l_uid "$FILE" | xargs)\""
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
