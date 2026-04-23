#!/usr/bin/env bash
NAME="ensure GDM screen locks when the user is idle"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

mkdir -p "$GD_db_dir"
cat > "$GD_screensaver_file" <<EOF
[org/gnome/desktop/session]
idle-delay=uint32 ${GD_idle_delay}

[org/gnome/desktop/screensaver]
lock-delay=uint32 ${GD_lock_delay}
EOF

dconf update 2>/dev/null || true

idle=$(grep -Prhs '^\s*idle-delay\s*=\s*uint32\s+\d+' "$GD_db_dir" 2>/dev/null \
    | awk '{print $NF}' | tail -1)
[ -n "$idle" ] && [ "$idle" -le "$GD_idle_delay" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0