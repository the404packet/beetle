#!/usr/bin/env bash
NAME="ensure logrotate is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

if [ -z "$RS_logrotate_dir" ]; then
    echo -e "${RED}FAILED${RESET} (logrotate dir not set)"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' logrotate 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q logrotate </dev/null >/dev/null 2>&1 || true
fi

drop_file="${RS_logrotate_dir}/rsyslog"
mkdir -p "$RS_logrotate_dir"

if [ -t 0 ] && [ -c /dev/tty ]; then
    echo -n "  Apply default logrotate policy to $drop_file? [y/n] (default: y): "
    read -r response </dev/tty
    response="${response:-y}"
    [[ "${response,,}" == "y" ]] || { echo -e "${RED}FAILED${RESET}"; exit 1; }
fi

cat > "$drop_file" <<'EOF'
/var/log/syslog /var/log/mail* /var/log/cron /var/log/warn /var/log/messages {
    daily
    rotate 14
    maxage 30
    compress
    missingok
    notifempty
    sharedscripts
    postrotate
        systemctl reload-or-restart rsyslog 2>/dev/null || true
    endscript
}
EOF

found=$(grep -Ps '^\s*(daily|weekly|monthly|rotate\s+\d+|maxage\s+\d+)' "$drop_file" 2>/dev/null | head -1)
[ -n "$found" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
