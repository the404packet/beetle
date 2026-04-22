#!/usr/bin/env bash
NAME="ensure GPG keys are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

found=0
for file in /etc/apt/trusted.gpg.d/*.gpg \
            /etc/apt/trusted.gpg.d/*.asc \
            /etc/apt/sources.list.d/*.gpg \
            /etc/apt/sources.list.d/*.asc; do
    [ -f "$file" ] && found=1 && break
done

[ "$found" -eq 1 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0