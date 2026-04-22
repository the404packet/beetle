#!/usr/bin/env bash
NAME="ensure GDM automatic mounting of removable media is disabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

mkdir -p "$GD_db_dir"
cat > "$GD_automount_file" <<'EOF'
[org/gnome/desktop/media-handling]
automount=false
automount-open=false
EOF

dconf update 2>/dev/null || true

grep -Prhsq '^\s*automount\s*=\s*false' "$GD_db_dir" 2>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0