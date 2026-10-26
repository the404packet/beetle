#!/usr/bin/env bash
# CIS 1.2.1.1 is a Manual control. Beetle detects and reports — it does not
# modify keyrings.

NAME="ensure GPG keys are configured"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

echo ""
echo -e "${YELLOW}  [MANUAL CHECK] GPG keys must be configured per site policy.${RESET}"
echo "  CIS 1.2.1.1 is a manual control — Beetle does not modify keyrings."
echo ""

echo -e "${CYAN}  Currently configured trusted keyrings:${RESET}"
found=false
for f in /etc/apt/trusted.gpg.d/*.gpg /etc/apt/trusted.gpg.d/*.asc \
         /etc/apt/sources.list.d/*.gpg /etc/apt/sources.list.d/*.asc; do
    [ -f "$f" ] && { echo "    $f"; found=true; }
done
echo ""

if $found; then
    echo "  Verify each key is correct for your package manager per site policy:"
    echo "    gpg --list-packets <keyring-file>"
    echo "    apt-cache policy"
    echo ""
    echo -e "${GREEN}SUCCESS${RESET} (trusted keyrings present — human review recommended)"
    exit 0
fi

echo -e "${RED}FAILED${RESET} (no trusted keyrings found)"
exit 1