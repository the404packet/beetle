#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.3.8
# Ensure nftables default deny firewall policy (Automated)
# =============================================================================
NAME="ensure nftables default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

fam="$NFT_table_family"; tbl="$NFT_table_name"; count="$NFT_chain_count"
for ((i=0; i<count; i++)); do
    n_var="NFT_chain_${i}_name";   name="${!n_var}"
    p_var="NFT_chain_${i}_policy"; policy="${!p_var}"
    nft chain "$fam" "$tbl" "$name" "{ policy ${policy} ; }" &>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
