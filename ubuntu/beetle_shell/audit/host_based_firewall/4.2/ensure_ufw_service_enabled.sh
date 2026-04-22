#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.2/ensure_ufw_service_enabled.sh
# CIS Ubuntu Benchmark — 4.2.3
# Ensure ufw service is enabled (Automated)
# =============================================================================
NAME="ensure ufw service is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

systemctl is-enabled ufw &>/dev/null \
    && ufw status | grep -q "Status: active" \
    && echo -e "${GREEN}HARDENED${RESET}"     \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
