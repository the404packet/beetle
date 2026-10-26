#!/usr/bin/env bash
NAME="ensure journald is configured to send logs to rsyslog"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' rsyslog 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q rsyslog </dev/null >/dev/null 2>&1 || true
fi

actual=$("$(readlink -f /bin/systemd-analyze)" cat-config systemd/journald.conf 2>/dev/null \
         | grep -Ps "^\s*ForwardToSyslog\s*=" | tail -1 \
         | awk -F= '{print $2}' | tr -d ' ')

if [ "$actual" = "yes" ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

conf="/etc/systemd/journald.conf"
[ -f "$conf" ] || touch "$conf"

if grep -Psq '^\s*ForwardToSyslog\s*=' "$conf"; then
    sed -i 's|^\s*ForwardToSyslog\s*=.*|ForwardToSyslog=yes|' "$conf"
else
    grep -Psq '^\s*\[Journal\]' "$conf" || echo "[Journal]" >> "$conf"
    echo "ForwardToSyslog=yes" >> "$conf"
fi

systemctl reload-or-restart systemd-journald 2>/dev/null || true

actual=$("$(readlink -f /bin/systemd-analyze)" cat-config systemd/journald.conf 2>/dev/null \
         | grep -Ps "^\s*ForwardToSyslog\s*=" | tail -1 \
         | awk -F= '{print $2}' | tr -d ' ')

[ "$actual" = "yes" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
