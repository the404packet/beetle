#!/usr/bin/env bash
NAME='ensure access to bootloader config is configured'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -f "$BL_grub_cfg" ] || { echo "ERROR: $BL_grub_cfg not found" >&2; echo -e "${RED}FAILED${RESET}"; exit 1; }

chown "${BL_owner}:${BL_group}" "$BL_grub_cfg"
chmod u-x,go-rwx "$BL_grub_cfg"

# Validate
read -r fmode fuid fgid < <(stat -Lc '%#a %u %g' "$BL_grub_cfg" 2>/dev/null)
perm_mask=$(( 8#$BL_perm_mask ))
flag=1
(( (8#${fmode//0/} & perm_mask) > 0 )) 2>/dev/null && flag=0
[ "$fuid" != "0" ] && flag=0
[ "$fgid" != "0" ] && flag=0

(( flag )) && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; } || { echo -e "${RED}FAILED${RESET}"; exit 1; }