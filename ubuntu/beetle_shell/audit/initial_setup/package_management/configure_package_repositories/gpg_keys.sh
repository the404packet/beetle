#!/usr/bin/env bash
NAME="ensure GPG keys are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

# CIS audit: verify keyrings exist in the standard locations.
# Full validation is manual (site policy); the audit only checks that
# some trusted keyring is present.
found=false
for f in /etc/apt/trusted.gpg.d/*.gpg /etc/apt/trusted.gpg.d/*.asc \
         /etc/apt/sources.list.d/*.gpg /etc/apt/sources.list.d/*.asc; do
    [ -f "$f" ] && { found=true; break; }
done

$found \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0