#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_ufw_uninstalled_with_nftables.sh
# CIS Ubuntu Benchmark — 4.3.2
# Ensure ufw is uninstalled or disabled with nftables (Automated)
# =============================================================================
NAME="ensure ufw is uninstalled or disabled with nftables"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

count="$NFT_banned_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_banned_${i}_name"; name="${!n_var}"
    is_package_installed "$name" || continue
    systemctl stop "$name" &>/dev/null; systemctl disable "$name" &>/dev/null
    apt-get purge -y "$name" &>/dev/null \
        && unset_package "$name"          \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
