#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_table_exists.sh
# CIS Ubuntu Benchmark — 4.3.4
# Ensure a nftables table exists (Automated)
# =============================================================================
NAME="ensure a nftables table exists"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

nft list tables 2>/dev/null | grep -q "${NFT_table_family}.*${NFT_table_name}" \
    && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }
nft add table "${NFT_table_family}" "${NFT_table_name}" &>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}"                             \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
