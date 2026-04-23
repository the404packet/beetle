#!/usr/bin/env bash
NAME="ensure all AppArmor profiles are enforcing"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

aa-enforce "$AA_profiles_dir"/* 2>/dev/null || true

complain=$(apparmor_status 2>/dev/null | awk '/profiles are in complain mode/{print $1}')
unconfined=$(apparmor_status 2>/dev/null | awk '/processes are unconfined but have a profile/{print $1}')

[ "${complain:-0}"   -gt 0 ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }
[ "${unconfined:-0}" -gt 0 ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }

echo -e "${GREEN}SUCCESS${RESET}"; exit 0