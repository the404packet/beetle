#!/usr/bin/env bash
NAME="ensure only one logging system is in use"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || true

# Determine which to keep based on module preference (default: journald)
if [ "${LJ_preferred_logging_system:-journald}" = "rsyslog" ]; then
    keep="rsyslog"
    kill="systemd-journald"
else
    keep="systemd-journald"
    kill="rsyslog"
fi

keep_active=$(systemctl is-active "$keep" 2>/dev/null)
kill_active=$(systemctl is-active "$kill" 2>/dev/null)

# If both are active, disable the non-preferred one
if [ "$keep_active" = "active" ] && [ "$kill_active" = "active" ]; then
    systemctl stop    "$kill" 2>/dev/null || true
    systemctl disable "$kill" 2>/dev/null || true
    systemctl mask    "$kill" 2>/dev/null || true
fi

# Preferred must be active
[ "$(systemctl is-active "$keep" 2>/dev/null)" = "active" ] || {
    echo -e "${RED}FAILED${RESET} (preferred $keep not active)"
    exit 1
}

echo -e "${GREEN}SUCCESS${RESET}"; exit 0