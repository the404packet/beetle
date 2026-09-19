#!/usr/bin/env bash
NAME='ensure address space layout randomization is enabled'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

name_var="PH_kparam_0_name"
value_var="PH_kparam_0_value"
param_name="${!name_var}"
param_value="${!value_var}"

flag=1
network_audit_sysctl_param "$param_name" "$param_value" || flag=0
network_audit_sysctl_file  "$param_name" "$param_value" || flag=0

(( flag )) \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0