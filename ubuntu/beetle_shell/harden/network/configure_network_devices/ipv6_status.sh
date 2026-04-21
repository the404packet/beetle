#!/usr/bin/env bash

NAME="ensure IPv6 status is identified"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$NETWORK_RAM_STORE" ] && source "$NETWORK_RAM_STORE"

ipv6_status="$NS_ipv6_status"
sysctl_count="$NS_ipv6_sysctl_count"

if [[ "$ipv6_status" == "disabled" ]]; then
    # disable via sysctl
    for ((i=0; i<sysctl_count; i++)); do
        key_var="NS_ipv6_sysctl_${i}"
        key="${!key_var}"
        sysctl -w "${key}=1" &>/dev/null

        # persist
        config_file="/etc/sysctl.d/60-ipv6.conf"
        if grep -Pq "^\s*${key}\s*=" "$config_file" 2>/dev/null; then
            sed -i "s|^\s*${key}\s*=.*|${key} = 1|" "$config_file"
        else
            echo "${key} = 1" >> "$config_file"
        fi
    done

    sysctl_disabled=true
    for ((i=0; i<sysctl_count; i++)); do
        key_var="NS_ipv6_sysctl_${i}"
        key="${!key_var}"
        val=$(sysctl "$key" 2>/dev/null | awk -F= '{print $2}' | tr -d ' ')
        [[ "$val" != "1" ]] && sysctl_disabled=false && break
    done

    if $sysctl_disabled; then
        echo -e "${GREEN}SUCCESS${RESET}"
    else
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi

elif [[ "$ipv6_status" == "enabled" ]]; then
    # enable via sysctl
    for ((i=0; i<sysctl_count; i++)); do
        key_var="NS_ipv6_sysctl_${i}"
        key="${!key_var}"
        sysctl -w "${key}=0" &>/dev/null

        config_file="/etc/sysctl.d/60-ipv6.conf"
        if grep -Pq "^\s*${key}\s*=" "$config_file" 2>/dev/null; then
            sed -i "s|^\s*${key}\s*=.*|${key} = 0|" "$config_file"
        else
            echo "${key} = 0" >> "$config_file"
        fi
    done

    ipv6_active=false
    if grep -Pqs -- '^\h*0\b' /sys/module/ipv6/parameters/disable; then
        ipv6_active=true
    fi

    sysctl_disabled=true
    for ((i=0; i<sysctl_count; i++)); do
        key_var="NS_ipv6_sysctl_${i}"
        key="${!key_var}"
        val=$(sysctl "$key" 2>/dev/null | awk -F= '{print $2}' | tr -d ' ')
        [[ "$val" != "1" ]] && sysctl_disabled=false && break
    done
    $sysctl_disabled && ipv6_active=false

    if $ipv6_active; then
        echo -e "${GREEN}SUCCESS${RESET}"
    else
        echo -e "${RED}FAILED${RESET}"
        exit 1
    fi
fi

exit 0