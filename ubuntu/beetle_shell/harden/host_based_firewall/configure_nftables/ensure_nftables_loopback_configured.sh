#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_loopback_configured.sh
# CIS Ubuntu Benchmark — 4.3.6
# Ensure nftables loopback traffic is configured (Automated)
# =============================================================================
NAME="ensure nftables loopback traffic is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

fam="$NFT_table_family"; tbl="$NFT_table_name"
nft add rule "$fam" "$tbl" input  "iif \"${NFT_lb_iface}\" accept"    &>/dev/null
nft add rule "$fam" "$tbl" output "oif \"${NFT_lb_iface}\" accept"    &>/dev/null
nft add rule "$fam" "$tbl" input  "ip saddr ${NFT_lb_deny_in} drop"   &>/dev/null
ip6tables -L &>/dev/null \
    && nft add rule "$fam" "$tbl" input "ip6 saddr ${NFT_lb_deny_in6} drop" &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
