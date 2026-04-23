#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.2/ensure_iptables_persistent_not_installed.sh
# CIS Ubuntu Benchmark — 4.2.2
# Ensure iptables-persistent is not installed with ufw (Automated)
#
# iptables-persistent conflicts with ufw rule management
# =============================================================================
NAME="ensure iptables-persistent is not installed with ufw"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

count="$UFW_banned_count"
for ((i=0; i<count; i++)); do
    n_var="UFW_banned_${i}_name"; name="${!n_var}"
    is_package_installed "$name" && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
