#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.1/ensure_single_firewall_utility.sh
# CIS Ubuntu Benchmark — 4.1.1
# Ensure a single firewall configuration utility is in use (Automated)
#
# Pass:  Exactly one of ufw / nftables / iptables is active
# Fail:  Zero or more than one backend active simultaneously
# =============================================================================
NAME="ensure single firewall utility is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

active_count=0
is_package_installed "ufw"      && systemctl is-enabled ufw      &>/dev/null && ((active_count++))
is_package_installed "nftables" && systemctl is-enabled nftables &>/dev/null && ((active_count++))
is_package_installed "iptables" \
    && iptables -L INPUT 2>/dev/null | grep -qv "^Chain\|^target\|^$"        && ((active_count++))

[ "$active_count" -eq 1 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
