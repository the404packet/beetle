#!/usr/bin/env bash

NAME="ensure root path integrity"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Root PATH integrity cannot be safely auto-remediated without risking breaking
# the system. This script corrects the permissions and ownership of PATH
# directories where possible, and reports items that require manual intervention.

flag=1
l_pmask="0022"
l_root_path=$(sudo -Hiu root env 2>/dev/null | grep '^PATH' | cut -d= -f2)

if [[ -z "$l_root_path" ]]; then
    echo "ERROR: Could not read root PATH" >&2
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

# Report structural issues — these require manual edits to shell profile files
grep -q "::" <<< "$l_root_path" && \
    echo "WARNING: root PATH contains an empty directory (::) — remove manually from shell profiles" >&2 && flag=0

grep -Pq ":\h*$" <<< "$l_root_path" && \
    echo "WARNING: root PATH has a trailing colon — remove manually from shell profiles" >&2 && flag=0

grep -Pq '(\h+|:)\.(:|\h*$)' <<< "$l_root_path" && \
    echo "WARNING: root PATH contains current working directory (.) — remove manually from shell profiles" >&2 && flag=0

unset a_path_loc
IFS=":" read -ra a_path_loc <<< "$l_root_path"

for l_path in "${a_path_loc[@]}"; do
    if [ -d "$l_path" ]; then
        l_fown=$(stat -Lc '%U' "$l_path")
        l_fmode=$(stat -Lc '%#a' "$l_path")

        if [[ "$l_fown" != "root" ]]; then
            echo "WARNING: Directory \"$l_path\" owned by \"$l_fown\" — cannot safely auto-chown; fix manually" >&2
            flag=0
        fi

        if (( (l_fmode & l_pmask) > 0 )); then
            new_mode=$(printf '%o' $(( l_fmode & ~l_pmask )))
            if chmod "$new_mode" "$l_path"; then
                echo "INFO: Fixed permissions on \"$l_path\" (was $l_fmode, now $new_mode)" >&2
            else
                echo "ERROR: Could not fix permissions on \"$l_path\"" >&2
                flag=0
            fi
        fi
    else
        echo "WARNING: \"$l_path\" in root PATH is not a directory — remove manually from shell profiles" >&2
        flag=0
    fi
done

# Re-validate
flag2=1
l_root_path2=$(sudo -Hiu root env 2>/dev/null | grep '^PATH' | cut -d= -f2)
grep -q "::" <<< "$l_root_path2" && flag2=0
grep -Pq ":\h*$" <<< "$l_root_path2" && flag2=0
grep -Pq '(\h+|:)\.(:|\h*$)' <<< "$l_root_path2" && flag2=0

IFS=":" read -ra a_path_loc2 <<< "$l_root_path2"
for l_path in "${a_path_loc2[@]}"; do
    if [ -d "$l_path" ]; then
        l_fown=$(stat -Lc '%U' "$l_path")
        l_fmode=$(stat -Lc '%#a' "$l_path")
        [[ "$l_fown" != "root" ]] && flag2=0
        (( (l_fmode & l_pmask) > 0 )) && flag2=0
    else
        flag2=0
    fi
done

if (( flag2 )); then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
