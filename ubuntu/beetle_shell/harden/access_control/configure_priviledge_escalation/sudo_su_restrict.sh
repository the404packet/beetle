#!/usr/bin/env bash

NAME='ensure access to the su command is restricted'
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

SU_GROUP="${SUDO_SU_RESTRICT_GROUP_NAME:-sugroup}"

flag=1

# Create the group if it doesn't exist
if ! getent group "$SU_GROUP" &>/dev/null; then
    groupadd "$SU_GROUP"
fi

# Add pam_wheel.so line if not present
PAM_LINE="auth required pam_wheel.so use_uid group=${SU_GROUP}"
if ! grep -Pi \
   '^\h*auth\h+(?:required|requisite)\h+pam_wheel\.so\h+(?:[^#\n\r]+\h+)?((?!\2)(use_uid\b|group=\H+\b))\h+(?:[^#\n\r]+\h+)?((?!\1)(use_uid\b|group=\H+\b))(\h+.*)?$' \
   /etc/pam.d/su 2>/dev/null | grep -q .; then
    echo "$PAM_LINE" >> /etc/pam.d/su
fi

# Validate group is empty
members=$(getent group "$SU_GROUP" | cut -d: -f4)
[ -n "$members" ] && flag=0

# Validate pam line exists
if ! grep -Pi \
   '^\h*auth\h+(?:required|requisite)\h+pam_wheel\.so\h+(?:[^#\n\r]+\h+)?((?!\2)(use_uid\b|group=\H+\b))\h+(?:[^#\n\r]+\h+)?((?!\1)(use_uid\b|group=\H+\b))(\h+.*)?$' \
   /etc/pam.d/su 2>/dev/null | grep -q .; then
    flag=0
fi

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0