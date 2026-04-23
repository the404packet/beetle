#!/usr/bin/env bash
NAME='ensure ptrace_scope is restricted'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

name_var="PH_kparam_1_name"; value_var="PH_kparam_1_value"
param_name="${!name_var}"
conf_file="$PH_sysctl_conf"

# Write value 1 (most permissive compliant) unless a stricter value already set
current=$(sysctl "$param_name" 2>/dev/null | awk -F= '{print $2}' | xargs)
if [[ "$current" =~ ^[23]$ ]]; then
    write_value="$current"
else
    write_value="1"
fi

network_harden_sysctl_param "$param_name" "$write_value" "" "$conf_file"

flag=1
actual=$(sysctl "$param_name" 2>/dev/null | awk -F= '{print $2}' | xargs)
[[ "$actual" =~ ^[123]$ ]] || flag=0
network_audit_sysctl_file "$param_name" "(1|2|3)" || flag=0

(( flag )) && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; } || { echo -e "${RED}FAILED${RESET}"; exit 1; }