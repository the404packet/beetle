#!/usr/bin/env bash
# =============================================================================
# audit/host_based_firewall/4.2/ensure_ufw_outbound_configured.sh
# CIS Ubuntu Benchmark — 4.2.5
# Ensure ufw outbound connections are configured (Manual)
# =============================================================================
NAME="ensure ufw outbound connections are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ufw status verbose 2>/dev/null \
    | grep -qi "Default:.*${UFW_policy_outgoing}.*\(outgoing\)" \
    && echo -e "${GREEN}HARDENED${RESET}"                        \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
