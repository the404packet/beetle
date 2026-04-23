#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_rules_permanent.sh
# CIS Ubuntu Benchmark — 4.3.10
# Ensure nftables rules are permanent (Automated)
#
# Compares md5 of live ruleset vs saved rules_file
# =============================================================================
NAME="ensure nftables rules are permanent"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

[ -f "$NFT_rules_file" ] || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
live_hash=$(nft list ruleset 2>/dev/null | md5sum)
file_hash=$(cat "$NFT_rules_file" 2>/dev/null | md5sum)
[ "$live_hash" = "$file_hash" ] \
    && echo -e "${GREEN}HARDENED${RESET}"  \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
