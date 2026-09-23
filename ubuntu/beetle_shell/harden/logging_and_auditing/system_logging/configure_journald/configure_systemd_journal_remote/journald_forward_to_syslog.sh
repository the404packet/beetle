#!/usr/bin/env bash
NAME="ensure journald ForwardToSyslog is disabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_dir="$LJ_config_drop_dir"
mkdir -p "$drop_dir"
drop_file="${drop_dir}/60-cis-journald.conf"

if grep -Psq '^\s*\[Journal\]' "$drop_file" 2>/dev/null; then
    sed -i '/^\s*ForwardToSyslog/d' "$drop_file"
    echo "ForwardToSyslog=no" >> "$drop_file"
else
    printf '%s\n' "[Journal]" "ForwardToSyslog=no" >> "$drop_file"
fi

systemctl reload-or-restart systemd-journald 2>/dev/null || true

actual=$("$(readlink -f /bin/systemd-analyze)" cat-config systemd/journald.conf 2>/dev/null \
         | grep -Ps "^\s*ForwardToSyslog\s*=" | tail -1 \
         | awk -F= '{print $2}' | tr -d ' ')

[ "$actual" = "no" ] && echo -e "${GREEN}SUCCESS${RESET}" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0