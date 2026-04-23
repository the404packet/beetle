#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.3/ensure_nftables_service_enabled.sh
# CIS Ubuntu Benchmark — 4.3.9
# Ensure nftables service is enabled (Automated)
# =============================================================================
NAME="ensure nftables service is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

systemctl enable --now nftables &>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}"     \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
