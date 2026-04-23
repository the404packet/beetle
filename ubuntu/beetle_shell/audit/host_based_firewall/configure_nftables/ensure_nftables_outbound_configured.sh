#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.3.7
# Ensure nftables outbound and established connections configured (Manual)
# =============================================================================
NAME="ensure nftables outbound and established connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

rules=$(nft list ruleset 2>/dev/null)
echo "$rules" | grep -q "ct state established,related accept" \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo "$rules" | grep -q "ct state new.*accept"                \
    || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
