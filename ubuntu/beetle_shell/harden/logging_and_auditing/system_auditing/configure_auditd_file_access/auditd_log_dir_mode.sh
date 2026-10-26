#!/usr/bin/env bash
NAME="ensure the audit log file directory mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

[ -f "$AC_config_file" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }
log_dir=$(dirname "$(awk -F= '/^\s*log_file\s*/{print $2}' "$AC_config_file" | xargs)")
[ -d "$log_dir" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }

chmod g-w,o-rwx "$log_dir"

mode=$(stat -Lc '%#a' "$log_dir")
[ $(( 8#$mode & 8#$AC_log_dir_perm_mask )) -gt 0 ] \
    && { echo -e "${RED}FAILED${RESET}"; exit 1; } \
    || echo -e "${GREEN}SUCCESS${RESET}"
exit 0