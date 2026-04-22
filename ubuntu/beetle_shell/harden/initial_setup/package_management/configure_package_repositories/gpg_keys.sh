#!/usr/bin/env bash
NAME="ensure GPG keys are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

echo ""
echo "  [MANUAL CHECK] GPG keys configuration"
echo "  Configured GPG keys found:"
for file in /etc/apt/trusted.gpg.d/*.gpg \
            /etc/apt/trusted.gpg.d/*.asc \
            /etc/apt/sources.list.d/*.gpg \
            /etc/apt/sources.list.d/*.asc; do
    [ -f "$file" ] && echo "    $file"
done
echo ""
echo "  Review the keys above and verify they are correct per site policy."
echo -n "  Are GPG keys correctly configured? (yes/no): "
read -r response

[ "$response" = "yes" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0