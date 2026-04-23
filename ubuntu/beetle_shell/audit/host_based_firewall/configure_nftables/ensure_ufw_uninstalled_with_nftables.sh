#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_ufw_uninstalled_with_nftables.sh
# CIS Ubuntu Benchmark — 4.3.2
# Ensure ufw is uninstalled or disabled with nftables (Automated)
#
# UFW and nftables manage same netfilter hooks — they must not coexist
# =============================================================================
NAME="ensure ufw is uninstalled or disabled with nftables"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

count="$NFT_banned_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_banned_${i}_name"; name="${!n_var}"
    if is_package_installed "$name"; then
        systemctl is-enabled "$name" &>/dev/null \
            && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
    fi
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
