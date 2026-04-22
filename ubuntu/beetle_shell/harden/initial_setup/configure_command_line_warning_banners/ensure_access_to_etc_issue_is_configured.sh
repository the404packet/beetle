#!/usr/bin/env bash
NAME='ensure access to /etc/issue is configured'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

chown root:root "$(readlink -e /etc/issue)"
chmod u-x,go-wx "$(readlink -e /etc/issue)"

read -r fmode fuid fgid < <(stat -Lc '%#a %u %g' /etc/issue 2>/dev/null)
perm_mask=$(( 8#${WB_1_perm_mask:-0133} ))
flag=1
(( (8#${fmode} & perm_mask) > 0 )) 2>/dev/null && flag=0
[ "$fuid" != "0" ] && flag=0; [ "$fgid" != "0" ] && flag=0

(( flag )) && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; } || { echo -e "${RED}FAILED${RESET}"; exit 1; }