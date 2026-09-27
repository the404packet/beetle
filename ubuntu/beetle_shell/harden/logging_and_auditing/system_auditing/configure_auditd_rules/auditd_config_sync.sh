#!/usr/bin/env bash
NAME="ensure the running and on disk configuration is the same"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

[ -z "$AR_rules_dir" ] && { echo -e "${RED}FAILED${RESET} (rules dir not set)"; exit 1; }
mkdir -p "$AR_rules_dir"

# Skip the interactive prompt in non-interactive runs
if [ -t 0 ] && [ -c /dev/tty ]; then
    echo -n "  Apply augenrules --load? [y/n] (default: y): "
    read -r response </dev/tty
    response="${response:-y}"
    [[ "${response,,}" == "y" ]] || { echo -e "${RED}FAILED${RESET} (user declined)"; exit 1; }
fi

augenrules --load 2>/dev/null || true

augenrules --check 2>/dev/null | grep -q "No change" \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
