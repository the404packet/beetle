#!/usr/bin/env bash
NAME="ensure the running and on disk configuration is the same"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

source "${BEETLE_SHELL_ROOT:-/usr/local/bin/beetle_shell}/lib/beetle_prompt.sh"

[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

umask 0027

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

[ -z "$AR_rules_dir" ] && { echo -e "${RED}FAILED${RESET} (rules dir not set)"; exit 1; }
mkdir -p "$AR_rules_dir"

# Ensure rule files have correct permissions
[ -n "$rules_file" ] && [ -f "$rules_file" ] && chmod 0640 "$rules_file" 2>/dev/null || true

response=$(beetle_prompt "Apply augenrules --load?" "y")
[ "$response" = "y" ] || { echo -e "${RED}FAILED${RESET} (user declined)"; exit 1; }

augenrules --load 2>/dev/null || true

augenrules --check 2>/dev/null | grep -q "No change" \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0