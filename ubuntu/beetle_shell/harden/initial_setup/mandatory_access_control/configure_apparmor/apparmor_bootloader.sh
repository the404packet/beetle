#!/usr/bin/env bash
NAME="ensure AppArmor is enabled in the bootloader configuration"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

grub_cfg="$AA_grub_config"
cmdline_key="$AA_grub_cmdline_key"
count="$AA_grub_param_count"

for ((i=0; i<count; i++)); do
    n_var="AA_grub_${i}_name";  name="${!n_var}"
    v_var="AA_grub_${i}_value"; value="${!v_var}"
    param="${name}=${value}"

    if grep -Pq "^\s*${cmdline_key}=.*${param}" "$grub_cfg" 2>/dev/null; then
        continue
    elif grep -Pq "^\s*${cmdline_key}=" "$grub_cfg" 2>/dev/null; then
        sed -i "s|^\(\s*${cmdline_key}=\"[^\"]*\)\"|\\1 ${param}\"|" "$grub_cfg"
    else
        echo "${cmdline_key}=\"${param}\"" >> "$grub_cfg"
    fi
done

update-grub 2>/dev/null

fail=0
for ((i=0; i<count; i++)); do
    n_var="AA_grub_${i}_name";  name="${!n_var}"
    v_var="AA_grub_${i}_value"; value="${!v_var}"
    result=$(grep '^\s*linux' "$AA_grub_cfg" 2>/dev/null | grep -v "${name}=${value}")
    [ -n "$result" ] && { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0