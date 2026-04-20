#!/usr/bin/env bash
NAME="ensure journald log file access is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}NOT HARDENED${RESET}"; exit 0; }

analyze_cmd="$(readlink -f /bin/systemd-analyze)"
tmpfiles_conf="$LJ_tmpfiles_config"
fail=0

while IFS= read -r l_file; do
    l_file="$(tr -d '# ' <<< "$l_file")"
    while IFS=: read -r logfile mode user group; do
        if [ -d "$logfile" ]; then
            perm_mask="0027"
            grep -Psq '^(\/run|\/var\/lib\/systemd)\b' <<< "$logfile" && perm_mask="0022"
        else
            perm_mask="0137"
        fi
        actual_mode=$(stat -c "%a" "$logfile" 2>/dev/null) || continue
        if [ $(( 8#$actual_mode & 8#${perm_mask} )) -gt 0 ]; then
            fail=1
        fi
    done <<< "$(awk '($1~/^(f|d)$/ && $2~/\/\S+/ && $3~/[0-9]{3,}/){print $2":"$3":"$4":"$5}' "$l_file" 2>/dev/null)"
done < <("$analyze_cmd" cat-config "$tmpfiles_conf" 2>/dev/null | tac | grep -Pio '^\h*#\h*\/[^#\n\r\h]+\.conf\b')

[ "$fail" -eq 0 ] && echo -e "${GREEN}HARDENED${RESET}" || echo -e "${RED}NOT HARDENED${RESET}"
exit 0