#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_base_chains_exist.sh
# CIS Ubuntu Benchmark — 4.3.5
# Ensure nftables base chains exist (Automated)
#
# Creates missing chains with hook + policy from firewall.json
# =============================================================================
NAME="ensure nftables base chains exist"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

family="$NFT_table_family"; table="$NFT_table_name"; count="$NFT_chain_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_chain_${i}_name";   name="${!n_var}"
    h_var="NFT_chain_${i}_hook";   hook="${!h_var}"
    p_var="NFT_chain_${i}_policy"; policy="${!p_var}"
    nft list chain "$family" "$table" "$name" &>/dev/null && continue
    nft add chain "$family" "$table" "$name" \
        "{ type filter hook $hook priority 0 ; policy $policy ; }" &>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
