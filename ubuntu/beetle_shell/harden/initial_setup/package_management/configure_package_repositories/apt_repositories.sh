#!/usr/bin/env bash
NAME="ensure package manager repositories are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

echo ""
echo "  [MANUAL CHECK] APT repository configuration"
echo "  Currently configured repositories:"
apt-cache policy 2>/dev/null | grep -E 'http|file:' | head -20
echo ""
echo "  Review the repositories above and verify they are correct per site policy."
echo -n "  Are repositories correctly configured? (yes/no): "
read -r response

[ "$response" = "yes" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0