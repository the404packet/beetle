#!/usr/bin/env bash

NAME="ensure IPv6 status is identified"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

ipv6_status="$NS_ipv6_status"
sysctl_count="$NS_ipv6_sysctl_count"

# check if IPv6 is disabled via kernel module
if grep -Pqs -- '^\h*0\b' /sys/module/ipv6/parameters/disable; then
    ipv6_active=true
else
    ipv6_active=false
fi

# check if IPv6 is disabled via sysctl
sysctl_disabled=true
for ((i=0; i<sysctl_count; i++)); do
    key_var="NS_ipv6_sysctl_${i}"
    key="${!key_var}"
    val=$(sysctl "$key" 2>/dev/null | awk -F= '{print $2}' | tr -d ' ')
    if [[ "$val" != "1" ]]; then
        sysctl_disabled=false
        break
    fi
done

$sysctl_disabled && ipv6_active=false

if [[ "$ipv6_status" == "enabled" ]]; then
    if $ipv6_active; then
        echo -e "${GREEN}HARDENED${RESET}"
    else
        echo -e "${RED}NOT HARDENED${RESET}"
    fi
elif [[ "$ipv6_status" == "disabled" ]]; then
    if $ipv6_active; then
        echo -e "${RED}NOT HARDENED${RESET}"
    else
        echo -e "${GREEN}HARDENED${RESET}"
    fi
fi

exit 0