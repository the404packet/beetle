#!/usr/bin/env bash
NAME="ensure audit log files group owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -f "$AC_config_file" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }
log_dir=$(dirname "$(awk -F= '/^\s*log_file\s*/{print $2}' "$AC_config_file" | xargs)")
[ -d "$log_dir" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }

find -L "$log_dir" -type f ! -group root ! -group "$AC_log_group" \
    -exec chgrp "$AC_log_group" {} +

sed -ri "s/^\s*#?\s*log_group\s*=\s*\S+(\s*#.*)?.*$/log_group = ${AC_log_group}\1/" \
    "$AC_config_file"

systemctl restart auditd 2>/dev/null || true

fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find -L "$log_dir" -type f ! -group root ! -group "$AC_log_group" -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0