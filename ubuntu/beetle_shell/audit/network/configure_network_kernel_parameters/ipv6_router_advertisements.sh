#!/usr/bin/env bash

NAME="ensure ipv6 router advertisements are not accepted"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

ipv6_disabled=$(check_ipv6_disabled)

if [ "$ipv6_disabled" == "yes" ]; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

failed=false
check_name="ipv6_router_advertisements"

count="$NP_ipv6_count"
for ((i=0; i<count; i++)); do
    name_var="NP_ipv6_${i}_name"
    value_var="NP_ipv6_${i}_value"
    chk_var="NP_ipv6_${i}_check"
    name="${!name_var}"
    value="${!value_var}"
    chk="${!chk_var}"

    [ "$chk" != "$check_name" ] && continue

    if ! network_audit_sysctl_param "$name" "$value" || \
       ! network_audit_sysctl_file "$name" "$value"; then
        failed=true; break
    fi
done

$failed && echo -e "${RED}NOT HARDENED${RESET}" || echo -e "${GREEN}HARDENED${RESET}"
exit 0