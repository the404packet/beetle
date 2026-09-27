#!/usr/bin/env bash
NAME="ensure journald ForwardToSyslog is disabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "journald" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

drop_dir="/etc/systemd/journald.conf.d"
drop_file="${drop_dir}/syslog.conf"
mkdir -p "$drop_dir"

if [ ! -f "$drop_file" ] || ! grep -Psq '^\s*\[Journal\]' "$drop_file"; then
    printf '%s\n' "[Journal]" > "$drop_file"
fi

sed -i -E '/^[[:space:]]*ForwardToSyslog[[:space:]]*=/d' "$drop_file" 2>/dev/null
echo "ForwardToSyslog=no" >> "$drop_file"

systemctl reload-or-restart systemd-journald 2>/dev/null || true

actual=$(systemd-analyze cat-config systemd/journald.conf 2>/dev/null \
         | grep -Ps "^\s*ForwardToSyslog\s*=" | tail -1 \
         | awk -F= '{print $2}' | tr -d ' ')

[ "$actual" = "no" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
