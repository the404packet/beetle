#!/usr/bin/env bash
NAME="ensure audit log files mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -f "$AC_config_file" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }
log_dir=$(dirname "$(awk -F= '/^\s*log_file\s*/{print $2}' "$AC_config_file" | xargs)")
[ -d "$log_dir" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }

find "$log_dir" -maxdepth 1 -type f -perm /"$AC_log_file_perm_mask" \
    -exec chmod u-x,g-wx,o-rwx {} +

fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find "$log_dir" -maxdepth 1 -type f -perm /"$AC_log_file_perm_mask" -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0