#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_rules_permanent.sh
# CIS Ubuntu Benchmark — 4.3.10
# Ensure nftables rules are permanent (Automated)
#
# Dumps live ruleset into rules_file defined in firewall.json
# =============================================================================
NAME="ensure nftables rules are permanent"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

nft list ruleset > "$NFT_rules_file" 2>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}"           \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
