#!/usr/bin/env bash
# =============================================================================
# harden/host_based_firewall/4.2/ensure_iptables_persistent_not_installed.sh
# CIS Ubuntu Benchmark — 4.2.2
# Ensure iptables-persistent is not installed with ufw (Automated)
# =============================================================================
NAME="ensure iptables-persistent is not installed with ufw"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$DPKG_RAM_STORE" ] && source "$DPKG_RAM_STORE"
[ -f "$FW_RAM_STORE"   ] && source "$FW_RAM_STORE"

count="$UFW_banned_count"
for ((i=0; i<count; i++)); do
    n_var="UFW_banned_${i}_name"; name="${!n_var}"
    is_package_installed "$name" || continue
    apt-get purge -y "$name" &>/dev/null \
        && unset_package "$name"          \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
done
echo -e "${GREEN}SUCCESS${RESET}"; exit 0
