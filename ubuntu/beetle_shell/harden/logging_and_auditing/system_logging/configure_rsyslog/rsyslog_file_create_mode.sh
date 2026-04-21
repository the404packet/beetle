#!/usr/bin/env bash
NAME="ensure rsyslog log file creation mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_file="${RS_config_dir}/${RS_drop_file}"
mkdir -p "$RS_config_dir"

sed -i '/^\s*\$FileCreateMode/d' "$drop_file" 2>/dev/null
echo "\$FileCreateMode $RS_file_create_mode" >> "$drop_file"

systemctl reload-or-restart "$RS_service" 2>/dev/null || true

mode=$(grep -rPs '^\s*\$FileCreateMode\s+\d+' \
       "$RS_config_file" "$RS_config_dir"/ 2>/dev/null \
       | tail -1 | awk '{print $2}' | tr -d ' ')

[ -n "$mode" ] && [ $(( 8#$mode & 8#0137 )) -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0