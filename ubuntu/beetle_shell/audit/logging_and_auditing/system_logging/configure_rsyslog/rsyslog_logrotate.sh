#!/usr/bin/env bash
NAME="ensure logrotate is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

require_present pkg logrotate

if [ -z "$RS_logrotate_config" ] || [ -z "$RS_logrotate_dir" ]; then
    echo -e "${RED}NOT HARDENED${RESET}"
    exit 0
fi

targets=()
[ -f "$RS_logrotate_config" ] && targets+=("$RS_logrotate_config")
if [ -d "$RS_logrotate_dir" ]; then
    while IFS= read -r -d '' f; do
        targets+=("$f")
    done < <(find "$RS_logrotate_dir" -maxdepth 1 -type f -print0 2>/dev/null)
fi

found=""
for f in "${targets[@]}"; do
    found=$(grep -Ps '^\s*(daily|weekly|monthly|rotate\s+\d+|maxage\s+\d+)' "$f" 2>/dev/null | head -1)
    [ -n "$found" ] && break
done

[ -n "$found" ] \
    && echo -e "${GREEN}HARDENED${RESET}" \
    || echo -e "${RED}NOT HARDENED${RESET}"
exit 0
