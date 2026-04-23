#!/usr/bin/env bash
NAME="ensure updates patches and additional security software are installed"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

apt-get update -qq 2>/dev/null
pending=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')

[ "$pending" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0