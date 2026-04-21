#!/usr/bin/env bash
NAME="ensure audit log files owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

[ -f "$AC_config_file" ] || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }
log_dir=$(dirname "$(awk -F= '/^\s*log_file\s*/{print $2}' "$AC_config_file" | xargs)")
[ -d "$log_dir" ] || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find "$log_dir" -maxdepth 1 -type f ! -user root -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0