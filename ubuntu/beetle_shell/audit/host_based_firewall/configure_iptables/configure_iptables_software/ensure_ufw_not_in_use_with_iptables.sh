#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_ufw_not_in_use_with_iptables.sh
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
    is_package_installed "$name" \
        && systemctl is-enabled "$name" &>/dev/null \
        && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
