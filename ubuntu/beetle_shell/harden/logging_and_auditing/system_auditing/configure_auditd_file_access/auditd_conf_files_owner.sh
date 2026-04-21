#!/usr/bin/env bash
NAME="ensure audit configuration files owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) ! -user root \
    -exec chown root {} +

fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) ! -user root -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0