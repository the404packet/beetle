#!/usr/bin/env bash

NAME="ensure ipv6 router advertisements are not accepted"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

ipv6_disabled=$(check_ipv6_disabled)

if [ "$ipv6_disabled" == "yes" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

failed=false
check_name="ipv6_router_advertisements"

count="$NP_ipv6_count"
for ((i=0; i<count; i++)); do
    name_var="NP_ipv6_${i}_name"
    value_var="NP_ipv6_${i}_value"
    flush_var="NP_ipv6_${i}_flush"
    chk_var="NP_ipv6_${i}_check"
    name="${!name_var}"
    value="${!value_var}"
    flush="${!flush_var}"
    chk="${!chk_var}"

    [ "$chk" != "$check_name" ] && continue

    network_harden_sysctl_param "$name" "$value" "$flush" "$NP_sysctl_conf_ipv6"

    if ! network_audit_sysctl_param "$name" "$value"; then
        failed=true; break
    fi
done

$failed && { echo -e "${RED}FAILED${RESET}"; exit 1; }
echo -e "${GREEN}SUCCESS${RESET}"
exit 0