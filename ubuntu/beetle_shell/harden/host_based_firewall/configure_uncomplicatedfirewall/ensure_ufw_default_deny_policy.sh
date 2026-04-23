#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.2/ensure_ufw_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.2.7
# Ensure ufw default deny firewall policy (Automated)
# =============================================================================
NAME="ensure ufw default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

ufw default "$UFW_policy_incoming" incoming &>/dev/null \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
ufw default "$UFW_policy_routed" routed     &>/dev/null \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
