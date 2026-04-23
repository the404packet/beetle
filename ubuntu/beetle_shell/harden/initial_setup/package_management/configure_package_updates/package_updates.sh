#!/usr/bin/env bash
NAME="ensure updates patches and additional security software are installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

apt-get update -qq 2>/dev/null
pending=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')

echo ""
echo "  [MANUAL CHECK] Pending package updates: ${pending}"
if [ "$pending" -gt 0 ]; then
    echo "  Packages to be upgraded:"
    apt-get -s upgrade 2>/dev/null | grep '^Inst' | awk '{print "   ", $2}' | head -20
    echo ""
    echo -n "  Press ENTER to run apt-get upgrade, or type 'no' to handle manually: "
    read -r response
    if [ "$response" = "no" ]; then
        echo -e "${RED}FAILED${RESET}"; exit 1
    fi
    apt-get upgrade -y 2>/dev/null \
        || { echo -e "${RED}FAILED${RESET}"; exit 1; }
fi

pending=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')
[ "$pending" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0