#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.3/ensure_nftables_service_enabled.sh
# CIS Ubuntu Benchmark — 4.3.9
# Ensure nftables service is enabled (Automated)
# =============================================================================
NAME="ensure nftables service is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

systemctl is-enabled nftables &>/dev/null \
    && echo -e "${GREEN}HARDENED${RESET}"  \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
