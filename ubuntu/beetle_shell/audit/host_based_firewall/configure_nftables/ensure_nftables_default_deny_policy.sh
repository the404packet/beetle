#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.3.8
# Ensure nftables default deny firewall policy (Automated)
# =============================================================================
NAME="ensure nftables default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

count="$NFT_chain_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_chain_${i}_name";   name="${!n_var}"
    p_var="NFT_chain_${i}_policy"; policy="${!p_var}"
    nft list chain "${NFT_table_family}" "${NFT_table_name}" "$name" 2>/dev/null \
        | grep -q "policy ${policy}" \
        || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
done
echo -e "${GREEN}HARDENED${RESET}"; exit 0
