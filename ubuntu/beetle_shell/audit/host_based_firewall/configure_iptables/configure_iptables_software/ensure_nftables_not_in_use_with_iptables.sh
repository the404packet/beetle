#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.4/ensure_nftables_not_in_use_with_iptables.sh
# CIS Ubuntu Benchmark — 4.4.1.2
# Ensure nftables is not in use with iptables (Automated)
# =============================================================================
NAME="ensure nftables is not in use with iptables"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"

is_package_installed "nftables" \
    && systemctl is-enabled nftables &>/dev/null \
    && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
