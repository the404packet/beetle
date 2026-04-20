#!/usr/bin/env bash
NAME="ensure systemd-journal-upload authentication is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

analyze_cmd="$(readlink -f /bin/systemd-analyze)"
conf="systemd/journal-upload.conf"
fail=0

for param in URL ServerKeyFile ServerCertificateFile TrustedCertificateFile; do
    found=$("$analyze_cmd" cat-config "$conf" 2>/dev/null \
            | grep -Ps "^\s*${param}\s*=\s*.+" | tail -1)
    if [ -z "$found" ]; then
        fail=1
    fi
done

[ "$fail" -eq 0 ] && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0