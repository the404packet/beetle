#!/usr/bin/env bash
NAME="ensure address space layout randomization is enabled"

GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# PH_kparam_0 = kernel.randomize_va_space, expected value 2
name_var="PH_kparam_0_name"
value_var="PH_kparam_0_value"
param_name="${!name_var}"
param_value="${!value_var}"
conf_file="$PH_sysctl_conf"

network_harden_sysctl_param "$param_name" "$param_value" "" "$conf_file"

# ── Verify runtime ──
actual=$(sysctl "$param_name" 2>/dev/null | awk -F= '{print $2}' | xargs)
if [[ "$actual" != "$param_value" ]]; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

# ── Verify file ──
if ! network_audit_sysctl_file "$param_name" "$param_value"; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0