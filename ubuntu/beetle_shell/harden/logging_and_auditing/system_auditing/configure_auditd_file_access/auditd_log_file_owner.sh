#!/usr/bin/env bash
NAME="ensure audit log files owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

[ -f "$AC_config_file" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }
log_dir=$(dirname "$(awk -F= '/^\s*log_file\s*/{print $2}' "$AC_config_file" | xargs)")
[ -d "$log_dir" ] || { echo -e "${RED}FAILED${RESET}"; exit 1; }

find "$log_dir" -maxdepth 1 -type f ! -user root -exec chown root {} +

fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find "$log_dir" -maxdepth 1 -type f ! -user root -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0