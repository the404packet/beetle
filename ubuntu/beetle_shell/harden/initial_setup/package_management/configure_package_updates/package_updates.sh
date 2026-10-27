#!/usr/bin/env bash
# CIS 1.2.2.1 is a Manual control. Beetle reports pending updates — it does
# not auto-upgrade (site policy determines timing).

NAME="ensure updates patches and additional security software are installed"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Refresh package lists; warn if it fails so a stale count isn't trusted blindly
apt-get update -qq >/dev/null 2>&1 || \
    echo -e "${YELLOW}  (apt update failed; counts may be stale)${RESET}"

# Simulate the upgrade once and reuse the result
sim=$(apt-get -s upgrade 2>/dev/null | grep '^Inst')
pending=$(printf '%s\n' "$sim" | grep -c '^Inst')

if [ "$pending" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${RESET} (no pending updates)"
    exit 0
fi

echo ""
echo -e "${YELLOW}  [MANUAL CHECK] ${pending} package updates pending.${RESET}"
echo "  CIS 1.2.2.1 is a manual control — apply per site policy:"
echo "    sudo apt-get upgrade -y"
echo "    # or: sudo apt-get dist-upgrade -y"
echo ""
echo "  Top packages to be upgraded:"
printf '%s\n' "$sim" | awk '{print "    " $2}' | head -10
echo ""
echo -e "${RED}FAILED${RESET} (${pending} pending)"
exit 1