#!/usr/bin/env bash
NAME="ensure the running and on disk configuration is the same"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

echo ""
echo "  [MANUAL CHECK] audit running vs on-disk config sync"
echo "  Will run: augenrules --load"
echo ""
echo -n "  Press ENTER to apply, or type 'no' to handle manually: "
read -r response

[ "$response" = "no" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

augenrules --load 2>/dev/null
ar_check_reboot

augenrules --check 2>/dev/null | grep -q "No change" \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0