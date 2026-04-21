#!/usr/bin/env bash

NAME='/etc/ssh/sshd_config file permission'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

EXPECTED_MASK=$(get_acc "sshd_config" perm_mask)
EXPECTED_OWNER=$(get_acc "sshd_config" owner)
EXPECTED_GROUP=$(get_acc "sshd_config" group)


# Fall back to defaults if JSON not loaded
EXPECTED_MASK="${EXPECTED_MASK:-0177}"
EXPECTED_OWNER="${EXPECTED_OWNER:-root}"
EXPECTED_GROUP="${EXPECTED_GROUP:-root}"



# echo -e "$EXPECTED_MASK $EXPECTED_OWNER $EXPECTED_GROUP"
# echo -e "$EXPECTED_MASK $EXPECTED_OWNER $EXPECTED_GROUP"
# echo -e "$EXPECTED_MASK $EXPECTED_OWNER $EXPECTED_GROUP"

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

# Check /etc/ssh/sshd_config
if [[ -f /etc/ssh/sshd_config ]]; then
    if ! check_file /etc/ssh/sshd_config; then
        flag=0
    fi
fi

# Check drop-in configs in sshd_config.d/
if (( flag )) && [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if ! check_file "$file"; then
            flag=0
            break
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0
