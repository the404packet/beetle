#!/usr/bin/env bash
# CIS 1.2.1.2 is a Manual control. Beetle detects and reports — it does not
# rewrite /etc/apt/sources.list.

NAME="ensure package manager repositories are configured"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

echo ""
echo -e "${YELLOW}  [MANUAL CHECK] Package repositories must be configured per site policy.${RESET}"
echo "  CIS 1.2.1.2 is a manual control — Beetle does not rewrite sources.list."
echo ""

echo -e "${CYAN}  Current APT repositories:${RESET}"
apt-cache policy 2>/dev/null | grep -E '^\s+\d+\s+https?://|file:' | head -20
echo ""

if apt-cache policy 2>/dev/null | grep -qE 'https?://|file:'; then
    echo "  Verify each repository is correct for your environment per site policy:"
    echo "    cat /etc/apt/sources.list"
    echo "    ls /etc/apt/sources.list.d/"
    echo ""
    echo -e "${GREEN}SUCCESS${RESET} (repositories present — human review recommended)"
    exit 0
fi

echo -e "${RED}FAILED${RESET} (no repositories configured)"
exit 1