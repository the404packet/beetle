#!/usr/bin/env bash

NAME='/etc/ssh/sshd_config file permission'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE"

EXPECTED_MASK=$(get_perm "/etc/ssh/sshd_config" perm_mask)
EXPECTED_OWNER=$(get_perm "/etc/ssh/sshd_config" owner)
EXPECTED_GROUP=$(get_perm "/etc/ssh/sshd_config" group)

EXPECTED_MASK="${EXPECTED_MASK:-0177}"
EXPECTED_OWNER="${EXPECTED_OWNER:-root}"
EXPECTED_GROUP="${EXPECTED_GROUP:-root}"

# Compute the target mode: strip all bits in the mask (600 safe default)
TARGET_MODE=$(printf '%o' $(( ~EXPECTED_MASK & 0777 )))

flag=1

fix_file() {
    local file="$1"
    if ! chmod "$TARGET_MODE" "$file" || ! chown "${EXPECTED_OWNER}:${EXPECTED_GROUP}" "$file"; then
        return 1
    fi
    return 0
}

if [[ -f /etc/ssh/sshd_config ]]; then
    if ! fix_file /etc/ssh/sshd_config; then
        flag=0
    fi
fi

if (( flag )) && [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if ! fix_file "$file"; then
            flag=0
            break
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
