#!/usr/bin/env bash
NAME="ensure logrotate is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

drop_file="${RS_logrotate_dir}/rsyslog"

echo ""
echo "  [MANUAL CHECK] logrotate configuration"
echo "  Will write default rotation policy to $drop_file:"
echo "    /var/log/syslog /var/log/mail* /var/log/cron /var/log/warn /var/log/messages {"
echo "      daily"
echo "      rotate 14"
echo "      maxage 30"
echo "      compress"
echo "      missingok"
echo "      notifempty"
echo "      sharedscripts"
echo "      postrotate"
echo "        systemctl reload-or-restart rsyslog"
echo "      endscript"
echo "    }"
echo ""
echo -n "  Press ENTER to apply, or type 'no' to handle manually: "
read -r response

if [ "$response" = "no" ]; then
    echo -e "${RED}FAILED${RESET}"; exit 1
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

found=$(grep -rPs '^\s*(daily|weekly|monthly|rotate\s+\d+|maxage\s+\d+)' \
        "$RS_logrotate_config" "$RS_logrotate_dir"/ 2>/dev/null | head -1)

[ -n "$found" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0