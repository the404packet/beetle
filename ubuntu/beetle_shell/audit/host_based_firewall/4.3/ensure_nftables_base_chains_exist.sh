#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_base_chains_exist.sh
# CIS Ubuntu Benchmark — 4.3.5
# Ensure nftables base chains exist (Automated)
#
# Chain list read from firewall.json → nftables.base_chains[]
# =============================================================================
NAME="ensure nftables base chains exist"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

count="$NFT_chain_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_chain_${i}_name"; name="${!n_var}"
    nft list chain "${NFT_table_family}" "${NFT_table_name}" "$name" &>/dev/null \
        || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
