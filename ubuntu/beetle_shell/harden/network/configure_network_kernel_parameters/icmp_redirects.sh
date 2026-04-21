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
        flush_var="NP_${section}_${i}_flush"
        chk_var="NP_${section}_${i}_check"
        name="${!name_var}"
        value="${!value_var}"
        flush="${!flush_var}"
        chk="${!chk_var}"

        [ "$chk" != "$check_name" ] && continue
        [[ "$section" == "ipv6" && "$ipv6_disabled" == "yes" ]] && continue

        if [[ "$section" == "ipv6" ]]; then
            conf_file="$NP_sysctl_conf_ipv6"
        else
            conf_file="$NP_sysctl_conf"
        fi

        network_harden_sysctl_param "$name" "$value" "$flush" "$conf_file"

        if ! network_audit_sysctl_param "$name" "$value"; then
            failed=true; break 2
        fi
    done
done

$failed && { echo -e "${RED}FAILED${RESET}"; exit 1; }
echo -e "${GREEN}SUCCESS${RESET}"
exit 0