#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.2/ensure_ufw_default_deny_policy.sh
# CIS Ubuntu Benchmark — 4.2.7
# Ensure ufw default deny firewall policy (Automated)
# =============================================================================
NAME="ensure ufw default deny firewall policy"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$FW_RAM_STORE" ] && source "$FW_RAM_STORE"

command -v ufw &>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y ufw &>/dev/null || true
ufw default "$UFW_policy_incoming" incoming &>/dev/null \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
routed_pol="$UFW_policy_routed"
[[ "$routed_pol" == "disabled" ]] && routed_pol="deny"
ufw default "$routed_pol" routed     &>/dev/null \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
