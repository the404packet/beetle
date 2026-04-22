#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_installed.sh
# CIS Ubuntu Benchmark — 4.3.1
# Ensure nftables is installed (Automated)
# =============================================================================
NAME="ensure nftables is installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

count="$NFT_pkg_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_pkg_${i}_name"; name="${!n_var}"
    is_package_installed "$name" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
