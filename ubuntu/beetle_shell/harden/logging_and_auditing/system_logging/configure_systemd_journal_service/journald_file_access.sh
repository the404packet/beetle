#!/usr/bin/env bash
NAME="ensure journald log file access is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$LOGGING_RAM_STORE" ] && source "$LOGGING_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

src="$LJ_tmpfiles_source"
dst="$LJ_tmpfiles_config"

if [ ! -f "$dst" ]; then
    cp "$src" "$dst" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
fi

# enforce 0640 on journal log files
sed -i 's/\(^f.*\/var\/log\/journal\/.*\)\s\+[0-9]\{3,4\}/\1 0640/' "$dst" 2>/dev/null
systemd-tmpfiles --create "$dst" 2>/dev/null

echo -e "${GREEN}SUCCESS${RESET}"; exit 0