#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.2/ensure_ufw_service_enabled.sh
# CIS Ubuntu Benchmark — 4.2.3
# Ensure ufw service is enabled (Automated)
# =============================================================================
NAME="ensure ufw service is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"

command -v ufw &>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y ufw &>/dev/null || true
systemctl enable --now ufw &>/dev/null || true
ufw --force enable          &>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
