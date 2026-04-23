#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.3.6
# Ensure nftables loopback traffic is configured (Automated)
# =============================================================================
NAME="ensure nftables loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

rules=$(nft list ruleset 2>/dev/null)
echo "$rules" | grep -q "iif \"${NFT_lb_iface}\" accept"  || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo "$rules" | grep -q "oif \"${NFT_lb_iface}\" accept"  || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
echo "$rules" | grep -q "${NFT_lb_deny_in}.*drop"         || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
ip6tables -L &>/dev/null \
    && { echo "$rules" | grep -q "${NFT_lb_deny_in6}.*drop" \
         || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }; }
echo -e "${GREEN}HARDENED${RESET}"; exit 0
