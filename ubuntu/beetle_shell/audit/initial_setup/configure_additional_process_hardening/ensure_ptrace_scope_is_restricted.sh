#!/usr/bin/env bash
NAME='ensure ptrace_scope is restricted'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

name_var="PH_kparam_1_name"
param_name="${!name_var}"

# Runtime: must be 1, 2, or 3
actual=$(sysctl "$param_name" 2>/dev/null | awk -F= '{print $2}' | xargs)
runtime_ok=false
[[ "$actual" =~ ^[123]$ ]] && runtime_ok=true

# File: any of 1, 2, 3 acceptable
file_ok=false
for v in 1 2 3; do
    if network_audit_sysctl_file "$param_name" "$v"; then
        file_ok=true
        break
    fi
done

if $runtime_ok && $file_ok; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
fi
exit 0