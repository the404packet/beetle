#!/usr/bin/env bash

NAME='ssh_public_host_key_permission'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED_MASK=$(get_acc "public_host_key" perm_mask)
EXPECTED_OWNER=$(get_acc "public_host_key" owner)
EXPECTED_GROUP=$(get_acc "public_host_key" group)

EXPECTED_MASK="${EXPECTED_MASK:-0133}"
EXPECTED_OWNER="${EXPECTED_OWNER:-root}"
EXPECTED_GROUP="${EXPECTED_GROUP:-root}"

perm_mask=$(( EXPECTED_MASK ))
flag=1

check_file() {
    local file="$1"
    local mode owner group
    read -r mode owner group < <(stat -Lc '%#a %U %G' "$file")
    if (( mode & perm_mask )) || [[ "$owner" != "$EXPECTED_OWNER" || "$group" != "$EXPECTED_GROUP" ]]; then
        return 1
    fi
    return 0
}

if [[ -d /etc/ssh ]]; then
    while IFS= read -r -d $'\0' file; do
        if ssh-keygen -lf "$file" &>/dev/null && \
           file "$file" | grep -Piq -- '\bopenssh\h+([^#\n\r]+\h+)?public\h+key\b'; then
            if ! check_file "$file"; then
                flag=0
                break
            fi
        fi
    done < <(find /etc/ssh -xdev -type f -print0)
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
