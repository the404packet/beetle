#!/usr/bin/env bash
NAME='ensure core dumps are restricted'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

flag=1

# Check limits.conf: * hard core 0
grep -Ps -- '^\h*\*\h+hard\h+core\h+0\b' \
    "$PH_limits_conf" /etc/security/limits.d/* 2>/dev/null | grep -q . || flag=0

# Check sysctl param and file: fs.suid_dumpable=0
name_var="PH_kparam_2_name"; value_var="PH_kparam_2_value"
param_name="${!name_var}"; param_value="${!value_var}"
network_audit_sysctl_param "$param_name" "$param_value" || flag=0
network_audit_sysctl_file  "$param_name" "$param_value" || flag=0

# Check systemd-coredump if installed
if systemctl list-unit-files 2>/dev/null | grep -q coredump; then
    grep -Pq '^\s*Storage\s*=\s*none\b' "$PH_coredump_conf" 2>/dev/null     || flag=0
    grep -Pq '^\s*ProcessSizeMax\s*=\s*0\b' "$PH_coredump_conf" 2>/dev/null || flag=0
fi

(( flag )) && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0