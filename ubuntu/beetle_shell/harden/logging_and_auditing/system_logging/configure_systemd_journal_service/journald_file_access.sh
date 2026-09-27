#!/usr/bin/env bash
NAME="ensure journald log file access is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

[ "${LJ_preferred_logging_system:-journald}" != "journald" ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

src="$LJ_tmpfiles_source"
dst="$LJ_tmpfiles_config"

if [ -z "$src" ] || [ -z "$dst" ]; then
    echo -e "${RED}FAILED${RESET} (tmpfiles paths not set)"
    exit 1
fi

if [ ! -f "$dst" ]; then
    cp "$src" "$dst" 2>/dev/null || { echo -e "${RED}FAILED${RESET}"; exit 1; }
fi

# Adjust mode on lines where the target is a journal file/dir entry
sed -i -E 's|^([fd][[:space:]]+/var/log/journal/[^[:space:]]+[[:space:]]+)[0-9]{3,4}|\10640|' "$dst" 2>/dev/null

systemd-tmpfiles --create "$dst" 2>/dev/null || true
sleep 1

# Verify — only check lines that actually have a mode
fail=0
while IFS= read -r line; do
    case "$line" in
        *"/var/log/journal/"*)
            mode=$(awk '{print $3}' <<< "$line")
            if [[ "$mode" =~ ^[0-7]{3,4}$ ]]; then
                perm=$(( 8#$mode ))
                if [ $(( perm & 0137 )) -gt 0 ]; then
                    fail=1
                    break
                fi
            fi
            ;;
    esac
done < "$dst"

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0
