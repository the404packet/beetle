#!/usr/bin/env bash
NAME="ensure ptrace_scope is restricted"

GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# PH_kparam_1 = kernel.yama.ptrace_scope, valid values 1, 2, or 3
name_var="PH_kparam_1_name"
param_name="${!name_var}"
conf_file="$PH_sysctl_conf"

# Preserve a stricter existing value (2 or 3); otherwise write 1.
current=$(sysctl "$param_name" 2>/dev/null | awk -F= '{print $2}' | xargs)
if [[ "$current" =~ ^[23]$ ]]; then
    write_value="$current"
else
    write_value="1"
fi

network_harden_sysctl_param "$param_name" "$write_value" "" "$conf_file"

# ── Verify runtime (1, 2, or 3 accepted) ──
failed=false
actual=$(sysctl "$param_name" 2>/dev/null | awk -F= '{print $2}' | xargs)
[[ "$actual" =~ ^[123]$ ]] || failed=true

# ── Verify file (accept 1, 2, or 3) ──
file_ok=false
for v in 1 2 3; do
    if network_audit_sysctl_file "$param_name" "$v"; then
        file_ok=true
        break
    fi
done
$file_ok || failed=true

if $failed; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
echo -e "${GREEN}SUCCESS${RESET}"
exit 0