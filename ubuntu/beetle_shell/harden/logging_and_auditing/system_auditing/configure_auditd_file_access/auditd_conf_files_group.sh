#!/usr/bin/env bash
NAME="ensure audit configuration files group owner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ -d /etc/audit ] || { echo -e "${RED}FAILED${RESET} (audit dir not present)"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) ! -group root \
    -exec chgrp root {} + 2>/dev/null || true

sleep 1
sleep 1
fail=0
while IFS= read -r -d $'\0' f; do
    fail=1; break
done < <(find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) ! -group root -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
