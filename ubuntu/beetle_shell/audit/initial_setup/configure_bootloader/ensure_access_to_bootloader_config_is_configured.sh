#!/usr/bin/env bash
NAME='ensure access to bootloader config is configured'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

flag=1
read -r fmode fuid fgid < <(stat -Lc '%a %u %g' "$BL_grub_cfg" 2>/dev/null)
[ -z "$fmode" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

mode_num=$(( 8#$fmode ))
perm_mask=$(( 8#$BL_perm_mask ))
(( (mode_num & perm_mask) == 0 )) || flag=0
[ "$fuid" != "0" ] && flag=0
[ "$fgid" != "0" ] && flag=0

(( flag )) && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0