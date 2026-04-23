#!/usr/bin/env bash
NAME="ensure GDM autorun-never is not overridden"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

mkdir -p "$GD_locks_dir"
cat > "$GD_autorun_lock" <<'EOF'
/org/gnome/desktop/media-handling/autorun-never
EOF

dconf update 2>/dev/null || true

grep -Psrilq '^\s*autorun-never' "$GD_locks_dir"/ 2>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0