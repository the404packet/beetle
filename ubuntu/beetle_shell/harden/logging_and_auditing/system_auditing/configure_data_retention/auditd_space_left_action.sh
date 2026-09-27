#!/usr/bin/env bash
NAME="ensure system warns when audit logs are low on space"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

if [ -z "$AC_config_file" ]; then
    echo -e "${RED}FAILED${RESET} (config file not set)"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

[ -f "$AC_config_file" ] || { echo -e "${RED}FAILED${RESET} (config file not present)"; exit 1; }

for idx in 4 5; do
    k_var="AC_${idx}_name";  key="${!k_var}"
    v_var="AC_${idx}_value"; val="${!v_var}"
    [ -z "$key" ] && continue
    if grep -Pq "^\s*${key}\s*=" "$AC_config_file" 2>/dev/null; then
        sed -i "s|^\s*${key}\s*=.*|${key} = ${val}|" "$AC_config_file"
    else
        echo "${key} = ${val}" >> "$AC_config_file"
    fi
done

systemctl reload-or-restart auditd 2>/dev/null || true

r1=$(grep -Pi "^\s*$AC_4_name\s*=\s*($AC_4_valid_values)\b" "$AC_config_file" 2>/dev/null)
r2=$(grep -Pi "^\s*$AC_5_name\s*=\s*($AC_5_valid_values)\b" "$AC_config_file" 2>/dev/null)

[ -n "$r1" ] && [ -n "$r2" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
