#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.2/ensure_ufw_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.2.5
# Ensure ufw outbound connections are configured (Manual)
# =============================================================================
NAME="ensure ufw outbound connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ufw default "$UFW_policy_outgoing" outgoing &>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}"                  \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
