#!/usr/bin/env bash
NAME="ensure AppArmor is enabled in the bootloader configuration"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
count="$AA_grub_param_count"
for ((i=0; i<count; i++)); do
    n_var="AA_grub_${i}_name";  name="${!n_var}"
    v_var="AA_grub_${i}_value"; value="${!v_var}"
    result=$(grep '^\s*linux' "$AA_grub_cfg" 2>/dev/null | grep -v "${name}=${value}")
    [ -n "$result" ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0