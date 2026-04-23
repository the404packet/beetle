#!/usr/bin/env bash

NAME="ensure access to the su command is restricted"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

SU_GROUP="${SUDO_SU_RESTRICT_GROUP_NAME:-sugroup}"

flag=1

# Check pam_wheel.so is configured with use_uid and the correct group
if ! grep -Pi \
   '^\h*auth\h+(?:required|requisite)\h+pam_wheel\.so\h+(?:[^#\n\r]+\h+)?((?!\2)(use_uid\b|group=\H+\b))\h+(?:[^#\n\r]+\h+)?((?!\1)(use_uid\b|group=\H+\b))(\h+.*)?$' \
   /etc/pam.d/su 2>/dev/null | grep -q .; then
    flag=0
fi

# Check the group exists and is empty
if (( flag )); then
    if ! getent group "$SU_GROUP" &>/dev/null; then
        flag=0
    else
        members=$(getent group "$SU_GROUP" | cut -d: -f4)
        [ -n "$members" ] && flag=0
    fi
fi

if (( flag )); then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi

exit 0