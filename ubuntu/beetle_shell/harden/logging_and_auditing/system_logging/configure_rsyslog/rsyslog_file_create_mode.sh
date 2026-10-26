#!/usr/bin/env bash
NAME="ensure rsyslog log file creation mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

if [ -z "$RS_config_dir" ] || [ -z "$RS_drop_file" ]; then
    echo -e "${RED}FAILED${RESET} (config paths not set)"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' "$RS_package" 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q "$RS_package" </dev/null >/dev/null 2>&1 || true
fi

drop_file="${RS_config_dir}/${RS_drop_file}"
mkdir -p "$RS_config_dir"

[ -f "$drop_file" ] && sed -i '/^\s*\$FileCreateMode/d' "$drop_file" 2>/dev/null
echo "\$FileCreateMode $RS_file_create_mode" >> "$drop_file"

systemctl reload-or-restart "$RS_service" 2>/dev/null || true

mode=$(grep -Ps '^\s*\$FileCreateMode\s+\d+' "$drop_file" 2>/dev/null | tail -1 | awk '{print $2}' | tr -d ' ')

[ -n "$mode" ] && [ $(( 8#$mode & 8#0137 )) -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
