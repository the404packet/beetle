#!/usr/bin/env bash
NAME='ensure access to /etc/motd is configured'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# motd is optional
[ ! -e /etc/motd ] && { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

read -r fmode fuid fgid < <(stat -Lc '%#a %u %g' /etc/motd 2>/dev/null)
perm_mask=$(( 8#${WB_0_perm_mask:-0133} ))
flag=1
(( (8#${fmode} & perm_mask) > 0 )) 2>/dev/null && flag=0
[ "$fuid" != "0" ] && flag=0
[ "$fgid" != "0" ] && flag=0

(( flag )) && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0