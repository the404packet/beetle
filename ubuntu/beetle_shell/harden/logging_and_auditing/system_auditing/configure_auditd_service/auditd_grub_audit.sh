#!/usr/bin/env bash
NAME="ensure auditing for processes prior to auditd is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

grub_cfg="$AD_grub_config"
cmdline_key="$AD_grub_cmdline_key"
param_name="AD_grub_0_name";  name="${!param_name}"
param_value="AD_grub_0_value"; value="${!param_value}"

[ -z "$grub_cfg" ]    && { echo -e "${RED}FAILED${RESET} (grub config path not set)"; exit 1; }
[ -z "$cmdline_key" ] && { echo -e "${RED}FAILED${RESET} (cmdline key not set)"; exit 1; }
[ -z "$name" ]        && { echo -e "${RED}FAILED${RESET} (param name not set)"; exit 1; }
[ -z "$value" ]       && { echo -e "${RED}FAILED${RESET} (param value not set)"; exit 1; }
[ -f "$grub_cfg" ]    || { echo -e "${RED}FAILED${RESET} (grub config missing)"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

if grep -Pq "^\s*${cmdline_key}=.*${name}=${value}\b" "$grub_cfg" 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"; exit 0
fi

if grep -Pq "^\s*${cmdline_key}=" "$grub_cfg" 2>/dev/null; then
    sed -i "s|^\(\s*${cmdline_key}=\"[^\"]*\)\"|\1 ${name}=${value}\"|" "$grub_cfg"
else
    echo "${cmdline_key}=\"${name}=${value}\"" >> "$grub_cfg"
fi

update-grub 2>/dev/null || true

result=$(find /boot -xdev -maxdepth 3 -type f -name 'grub.cfg' \
         -exec grep -Ph -- '^\h*linux' {} + 2>/dev/null \
         | grep -v "${name}=${value}")

[ -z "$result" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
