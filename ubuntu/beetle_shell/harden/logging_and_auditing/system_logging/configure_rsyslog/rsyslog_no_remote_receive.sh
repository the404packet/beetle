#!/usr/bin/env bash
NAME="ensure rsyslog is not configured to receive logs from a remote client"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
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

targets=("$RS_config_file")
while IFS= read -r -d '' f; do
    targets+=("$f")
done < <(find "$RS_config_dir" -maxdepth 2 -type f -name '*.conf' -print0 2>/dev/null)

for f in "${targets[@]}"; do
    [ -f "$f" ] || continue
    sed -i '/^\s*module(load="imtcp")/Id'  "$f" 2>/dev/null || true
    sed -i '/^\s*input(type="imtcp"/Id'    "$f" 2>/dev/null || true
    sed -i '/^\s*\$ModLoad\s\+imtcp/Id'    "$f" 2>/dev/null || true
    sed -i '/^\s*\$InputTCPServerRun/Id'   "$f" 2>/dev/null || true
done

systemctl reload-or-restart "$RS_service" 2>/dev/null || true

fail=0
for f in "$RS_config_file" "$RS_config_dir"; do
    [ -e "$f" ] || continue
    grep -rPsi '^\s*module\(load="?imtcp"?\)' "$f" 2>/dev/null && fail=1
    grep -rPsi '^\s*input\(type="?imtcp"?\b'  "$f" 2>/dev/null && fail=1
    grep -rPsi '^\s*\$ModLoad\s+imtcp\b'      "$f" 2>/dev/null && fail=1
    grep -rPsi '^\s*\$InputTCPServerRun\b'     "$f" 2>/dev/null && fail=1
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
