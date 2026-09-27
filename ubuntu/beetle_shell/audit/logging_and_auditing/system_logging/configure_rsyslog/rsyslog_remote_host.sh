#!/usr/bin/env bash
NAME="ensure rsyslog is configured to send logs to a remote log host"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

[ "${LJ_preferred_logging_system:-journald}" != "rsyslog" ] && { echo -e "${GREEN}HARDENED${RESET}"; exit 0; }

require_present pkg rsyslog

if [ -z "$RS_config_file" ] || [ -z "$RS_config_dir" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

targets=("$RS_config_file")
if [ -d "$RS_config_dir" ]; then
    while IFS= read -r -d '' f; do
        targets+=("$f")
    done < <(find "$RS_config_dir" -maxdepth 2 -type f -name '*.conf' -print0 2>/dev/null)
fi

found_basic=""
found_adv=""
for f in "${targets[@]}"; do
    [ -f "$f" ] || continue
    found_basic=$(grep -Hs '^\*\.\*.*@@' "$f" 2>/dev/null | head -1)
    found_adv=$(grep -Hsi '^\s*([^#]+\s+)?action\(([^#]+\s+)?\btarget=' "$f" 2>/dev/null | head -1)
    [ -n "$found_basic" ] && break
    [ -n "$found_adv" ] && break
done

[ -n "$found_basic" ] || [ -n "$found_adv" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
