#!/usr/bin/env bash
NAME="ensure audit configuration files mode is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' auditd 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q auditd audispd-plugins </dev/null >/dev/null 2>&1 || true
fi

find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) \
    -exec chmod u-x,g-wx,o-rwx {} +

fail=0
while IFS= read -r -d $'\0' f; do
    mode=$(stat -Lc '%#a' "$f")
    [ $(( 8#$mode & 8#$AC_conf_perm_mask )) -gt 0 ] && { fail=1; break; }
done < <(find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) -print0)

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0