#!/usr/bin/env bash
NAME="ensure audit_backlog_limit is sufficient"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

grub_cfg="$AD_grub_config"
cmdline_key="$AD_grub_cmdline_key"
param_name="AD_grub_1_name";  name="${!param_name}"
param_value="AD_grub_1_value"; value="${!param_value}"

if grep -Pq "^\s*${cmdline_key}=.*${name}=\d+" "$grub_cfg" 2>/dev/null; then
    # update existing value
    sed -i "s|${name}=[0-9]*|${name}=${value}|g" "$grub_cfg"
elif grep -Pq "^\s*${cmdline_key}=" "$grub_cfg" 2>/dev/null; then
    sed -i "s|^\(\s*${cmdline_key}=\"[^\"]*\)\"|\\1 ${name}=${value}\"|" "$grub_cfg"
else
    echo "${cmdline_key}=\"${name}=${value}\"" >> "$grub_cfg"
fi

update-grub 2>/dev/null

result=$(find /boot -type f -name 'grub.cfg' \
         -exec grep -Ph -- '^\h*linux' {} + 2>/dev/null \
         | grep -Pv "${name}=\d+\b")

[ -z "$result" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0