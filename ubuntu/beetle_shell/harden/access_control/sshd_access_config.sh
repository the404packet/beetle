#!/usr/bin/env bash

NAME='restrict ssh access using allow/deny list of user/grp'
SEVERITY='strict'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Requires BEETLE_SSH_ALLOW_GROUPS or BEETLE_SSH_ALLOW_USERS to be set
# by the operator before running, e.g. BEETLE_SSH_ALLOW_GROUPS="sshusers"
# Falls back to a safe default of allowing only sudo group
ALLOW_GROUPS="${BEETLE_SSH_ALLOW_GROUPS:-sudo}"

flag=1

if grep -Piq '^\s*(Allow|Deny)(Users|Groups)\b' "$SSHD_CONFIG" 2>/dev/null; then
    # Already has a directive — do not overwrite operator config
    :
else
    echo "AllowGroups $ALLOW_GROUPS" >> "$SSHD_CONFIG"
fi

# Apply to drop-ins if they override
if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*(Allow|Deny)(Users|Groups)\b' "$file" 2>/dev/null; then
            : # Already set in drop-in, leave it
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
if ! sshd -T 2>/dev/null | grep -Piq '^\h*(allow|deny)(users|groups)\h+\H+'; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
