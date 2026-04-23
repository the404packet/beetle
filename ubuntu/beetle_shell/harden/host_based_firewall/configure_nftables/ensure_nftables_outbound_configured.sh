#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.3.7
# Ensure nftables outbound and established connections configured (Manual)
# =============================================================================
NAME="ensure nftables outbound and established connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

fam="$NFT_table_family"; tbl="$NFT_table_name"
nft add rule "$fam" "$tbl" input  "ct state established,related accept"     &>/dev/null
nft add rule "$fam" "$tbl" output "ct state new,established,related accept" &>/dev/null
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
