#!/usr/bin/env bash

NAME="ensure reverse path filtering is enabled"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

failed=false
check_name="reverse_path_filter"

count="$NP_ipv4_count"
for ((i=0; i<count; i++)); do
    name_var="NP_ipv4_${i}_name"
    value_var="NP_ipv4_${i}_value"
    flush_var="NP_ipv4_${i}_flush"
    chk_var="NP_ipv4_${i}_check"
    name="${!name_var}"
    value="${!value_var}"
    flush="${!flush_var}"
    chk="${!chk_var}"

    [ "$chk" != "$check_name" ] && continue

    network_harden_sysctl_param "$name" "$value" "$flush" "$NP_sysctl_conf"

    if ! network_audit_sysctl_param "$name" "$value"; then
        failed=true; break
    fi
done

$failed && { echo -e "${RED}FAILED${RESET}"; exit 1; }
echo -e "${GREEN}SUCCESS${RESET}"
exit 0