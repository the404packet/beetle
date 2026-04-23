#!/usr/bin/env bash

NAME="ensure root path integrity"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

flag=1
l_pmask="0022"
l_root_path=$(sudo -Hiu root env 2>/dev/null | grep '^PATH' | cut -d= -f2)

if [[ -z "$l_root_path" ]]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

# Empty directory (::)
grep -q "::" <<< "$l_root_path" && flag=0

# Trailing colon
grep -Pq ":\h*$" <<< "$l_root_path" && flag=0

# Current working directory (.)
grep -Pq '(\h+|:)\.(:|\h*$)' <<< "$l_root_path" && flag=0

unset a_path_loc
IFS=":" read -ra a_path_loc <<< "$l_root_path"

for l_path in "${a_path_loc[@]}"; do
    if [ -d "$l_path" ]; then
        read -r l_fmode l_fown <<< "$(stat -Lc '%#a %U' "$l_path")"
        [[ "$l_fown" != "root" ]] && flag=0
        (( (l_fmode & l_pmask) > 0 )) && flag=0
    else
        flag=0
    fi
done

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
