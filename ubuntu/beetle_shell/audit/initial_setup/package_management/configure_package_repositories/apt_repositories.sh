#!/usr/bin/env bash
NAME="ensure package manager repositories are configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

repos=$(apt-cache policy 2>/dev/null | grep -c 'http')
[ "$repos" -gt 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0