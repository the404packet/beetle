#!/usr/bin/env bash

NAME="ensure icmp redirects are not accepted"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

ipv6_disabled=$(check_ipv6_disabled)
failed=false
check_name="icmp_redirects"

for section in ipv4 ipv6; do
    count_var="NP_${section}_count"
    count="${!count_var}"
    for ((i=0; i<count; i++)); do
        name_var="NP_${section}_${i}_name"
        value_var="NP_${section}_${i}_value"
        chk_var="NP_${section}_${i}_check"
        name="${!name_var}"
        value="${!value_var}"
        chk="${!chk_var}"

        [ "$chk" != "$check_name" ] && continue
        [[ "$section" == "ipv6" && "$ipv6_disabled" == "yes" ]] && continue

        if ! network_audit_sysctl_param "$name" "$value" || \
           ! network_audit_sysctl_file "$name" "$value"; then
            failed=true; break 2
        fi
    done
done

$failed && echo -e "${RED}NOT HARDENED${RESET}" || echo -e "${GREEN}HARDENED${RESET}"
exit 0