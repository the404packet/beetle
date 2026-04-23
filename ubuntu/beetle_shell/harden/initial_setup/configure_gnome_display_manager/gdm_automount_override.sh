#!/usr/bin/env bash
NAME="ensure GDM disabling automatic mounting is not overridden"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

mkdir -p "$GD_locks_dir"
cat > "$GD_automount_lock" <<'EOF'
/org/gnome/desktop/media-handling/automount
/org/gnome/desktop/media-handling/automount-open
EOF

dconf update 2>/dev/null || true

fail=0
for key in "automount" "automount-open"; do
    grep -Psrilq "^\s*${key}" "$GD_locks_dir"/ 2>/dev/null || { fail=1; break; }
done

[ "$fail" -eq 0 ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0