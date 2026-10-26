#!/usr/bin/env bash
NAME="ensure audit log files group owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -z "$AC_config_file" ] && { echo -e "${RED}FAILED${RESET}"; exit 1; }
[ -f "$AC_config_file" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }
[ -z "$AC_log_group" ] && { echo -e "${RED}FAILED${RESET} (log_group not set)"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

log_dir=$(dirname "$(awk -F= '/^\s*log_file\s*/{print $2}' "$AC_config_file" | xargs)")
[ -d "$log_dir" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }

find "$log_dir" -xdev -maxdepth 1 -type f ! -group root ! -group "$AC_log_group" \
    -exec chgrp "$AC_log_group" {} + 2>/dev/null || true

sed -ri "s/^\s*#?\s*log_group\s*=\s*\S+(\s*#.*)?.*$/log_group = ${AC_log_group}\1/" \
    "$AC_config_file"

systemctl reload-or-restart auditd 2>/dev/null || true

fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find "$log_dir" -xdev -maxdepth 1 -type f ! -group root ! -group "$AC_log_group" -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
