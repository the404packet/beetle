#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.4/ensure_ufw_not_in_use_with_iptables.sh
# CIS Ubuntu Benchmark — 4.4.1.3
# Ensure ufw is not in use with iptables (Automated)
# =============================================================================
NAME="ensure ufw is not in use with iptables"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

count="$IPT_banned_count"
for ((i=0; i<count; i++)); do
    n_var="IPT_banned_${i}_name"; name="${!n_var}"
    is_package_installed "$name" || continue
    systemctl stop "$name" &>/dev/null; systemctl disable "$name" &>/dev/null
    apt-get purge -y "$name" &>/dev/null \
        && unset_package "$name"           \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
