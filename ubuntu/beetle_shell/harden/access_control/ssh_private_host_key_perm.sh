#!/usr/bin/env bash

NAME='ssh_private_host_key_permission'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED_MASK=$(get_acc "private_host_key" perm_mask)
EXPECTED_OWNER=$(get_acc "private_host_key" owner)
EXPECTED_GROUP=$(get_acc "private_host_key" group)

EXPECTED_MASK="${EXPECTED_MASK:-0177}"
EXPECTED_OWNER="${EXPECTED_OWNER:-root}"
EXPECTED_GROUP="${EXPECTED_GROUP:-root}"

TARGET_MODE=$(printf '%o' $(( ~EXPECTED_MASK & 0777 )))
flag=1

if [[ -d /etc/ssh ]]; then
    while IFS= read -r -d $'\0' file; do
        if ssh-keygen -lf "$file" &>/dev/null && \
           file "$file" | grep -Piq -- '\bopenssh\h+([^#\n\r]+\h+)?private\h+key\b'; then
            if ! chmod "$TARGET_MODE" "$file" || \
               ! chown "${EXPECTED_OWNER}:${EXPECTED_GROUP}" "$file"; then
                flag=0
                break
            fi
        fi
    done < <(find /etc/ssh -xdev -type f -print0)
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
