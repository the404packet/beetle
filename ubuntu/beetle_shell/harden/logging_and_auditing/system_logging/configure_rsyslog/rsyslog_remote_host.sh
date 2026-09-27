#!/usr/bin/env bash
NAME="ensure rsyslog is configured to send logs to a remote log host"
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

if [ -z "$RS_config_file" ] || [ -z "$RS_config_dir" ]; then
    echo -e "${RED}FAILED${RESET} (config paths not set)"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! dpkg-query -W -f='${Status}' "$RS_package" 2>/dev/null | grep -q "install ok installed"; then
    apt-get install -y -q "$RS_package" </dev/null >/dev/null 2>&1 || true
fi

drop_file="${RS_config_dir}/${RS_drop_file}"
if grep -Hs '^\*\.\*.*@@' "$drop_file" 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi
if grep -Hsi '^\s*([^#]+\s+)?action\(([^#]+\s+)?\btarget=' "$drop_file" 2>/dev/null; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo ""
echo -e "${YELLOW}  [MANUAL CHECK] rsyslog remote log host is not configured.${RESET}"
echo "  CIS 4.2.2.x requires forwarding logs to a remote log server."
echo "  Beetle cannot determine your remote server's address."
echo ""
echo "  Configure it in:"
echo "    ${drop_file}"
echo ""
echo "  Example rule:"
echo "    *.* action(type=\"omfwd\" target=\"<YOUR_REMOTE_SERVER>\" port=\"514\" protocol=\"tcp\""
echo "     action.resumeRetryCount=\"100\""
echo "     queue.type=\"LinkedList\" queue.size=\"1000\")"
echo ""
echo "  Then: systemctl restart rsyslog"
echo ""
echo -e "${RED}FAILED${RESET} (manual configuration required)"
exit 1
