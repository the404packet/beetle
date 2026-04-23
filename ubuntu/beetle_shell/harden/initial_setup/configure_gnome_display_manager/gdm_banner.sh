#!/usr/bin/env bash
NAME="ensure GDM login banner is configured"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

mkdir -p "$GD_gdm_db_dir" "$GD_profile_dir"

grep -q '\[org/gnome/login-screen\]' "$GD_banner_file" 2>/dev/null || \
cat > "$GD_banner_file" <<EOF
[org/gnome/login-screen]
banner-message-enable=true
banner-message-text='${GD_banner_text}'
EOF

grep -Pq 'user-db:user' "$GD_profile_file" 2>/dev/null || \
cat > "$GD_profile_file" <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

dconf update 2>/dev/null || true

enabled=$(grep -Phs '^\s*banner-message-enable\s*=\s*true' "$GD_banner_file" 2>/dev/null)
[ -n "$enabled" ] \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0