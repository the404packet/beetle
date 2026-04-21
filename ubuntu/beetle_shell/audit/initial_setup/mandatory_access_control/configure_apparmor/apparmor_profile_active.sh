#!/usr/bin/env bash
NAME="ensure all AppArmor profiles are in enforce or complain mode"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

loaded=$(apparmor_status 2>/dev/null | awk '/profiles are loaded/{print $1}')
enforce=$(apparmor_status 2>/dev/null | awk '/profiles are in enforce mode/{print $1}')
complain=$(apparmor_status 2>/dev/null | awk '/profiles are in complain mode/{print $1}')
unconfined=$(apparmor_status 2>/dev/null | awk '/processes are unconfined but have a profile/{print $1}')

[ -z "$loaded" ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
[ "${unconfined:-0}" -gt 0 ] && { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
[ $(( ${enforce:-0} + ${complain:-0} )) -eq "${loaded}" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0