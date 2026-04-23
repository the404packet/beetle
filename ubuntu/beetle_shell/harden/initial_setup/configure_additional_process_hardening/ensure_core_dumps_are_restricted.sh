#!/usr/bin/env bash
NAME='ensure core dumps are restricted'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# Set limits.conf
if ! grep -Ps -- '^\h*\*\h+hard\h+core\h+0\b' \
        "$PH_limits_conf" /etc/security/limits.d/* 2>/dev/null | grep -q .; then
    echo "* hard core 0" >> "$PH_limits_conf"
fi

# Set sysctl
name_var="PH_kparam_2_name"; value_var="PH_kparam_2_value"
param_name="${!name_var}"; param_value="${!value_var}"
network_harden_sysctl_param "$param_name" "$param_value" "" "$PH_sysctl_conf"

# Handle systemd-coredump if installed
if systemctl list-unit-files 2>/dev/null | grep -q coredump; then
    mkdir -p "$(dirname "$PH_coredump_conf")"
    if grep -Pq '^\s*Storage\s*=' "$PH_coredump_conf" 2>/dev/null; then
        sed -i 's|^\s*Storage\s*=.*|Storage=none|' "$PH_coredump_conf"
    else
        echo "Storage=none" >> "$PH_coredump_conf"
    fi
    if grep -Pq '^\s*ProcessSizeMax\s*=' "$PH_coredump_conf" 2>/dev/null; then
        sed -i 's|^\s*ProcessSizeMax\s*=.*|ProcessSizeMax=0|' "$PH_coredump_conf"
    else
        echo "ProcessSizeMax=0" >> "$PH_coredump_conf"
    fi
    systemctl daemon-reload
fi

# Validate
flag=1
grep -Ps -- '^\h*\*\h+hard\h+core\h+0\b' \
    "$PH_limits_conf" /etc/security/limits.d/* 2>/dev/null | grep -q . || flag=0
network_audit_sysctl_param "$param_name" "$param_value" || flag=0
network_audit_sysctl_file  "$param_name" "$param_value" || flag=0

(( flag )) && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; } || { echo -e "${RED}FAILED${RESET}"; exit 1; }