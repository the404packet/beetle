#!/usr/bin/env bash
NAME="ensure rsyslog is not configured to receive logs from a remote client"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

for f in "$RS_config_file" $(find "$RS_config_dir"/ -type f -name '*.conf' 2>/dev/null); do
    sed -i '/^\s*module(load="imtcp")/Id'    "$f" 2>/dev/null
    sed -i '/^\s*input(type="imtcp"/Id'      "$f" 2>/dev/null
    sed -i '/^\s*\$ModLoad\s\+imtcp/Id'      "$f" 2>/dev/null
    sed -i '/^\s*\$InputTCPServerRun/Id'     "$f" 2>/dev/null
done

systemctl reload-or-restart "$RS_service" 2>/dev/null || true

fail=0
for f in "$RS_config_file" "$RS_config_dir"/; do
    grep -rPsi '^\s*module\(load="?imtcp"?\)' "$f" 2>/dev/null && fail=1
    grep -rPsi '^\s*input\(type="?imtcp"?\b'  "$f" 2>/dev/null && fail=1
    grep -rPsi '^\s*\$ModLoad\s+imtcp\b'      "$f" 2>/dev/null && fail=1
    grep -rPsi '^\s*\$InputTCPServerRun\b'     "$f" 2>/dev/null && fail=1
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0