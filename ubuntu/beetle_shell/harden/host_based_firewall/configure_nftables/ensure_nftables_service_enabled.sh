#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_service_enabled.sh
# CIS Ubuntu Benchmark — 4.3.9
# Ensure nftables service is enabled (Automated)
# =============================================================================
NAME="ensure nftables service is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"
rules_file="${NFT_rules_file:-/etc/nftables.conf}"
if [[ ! -s "$rules_file" ]] || grep -q "UNSECURED" "$rules_file" 2>/dev/null; then
    nft list ruleset > "$rules_file" 2>/dev/null || true
    if [[ ! -s "$rules_file" ]]; then
        echo "flush ruleset" > "$rules_file"
    fi
fi
systemctl unmask nftables &>/dev/null || true
systemctl enable --now nftables &>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}"     \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
