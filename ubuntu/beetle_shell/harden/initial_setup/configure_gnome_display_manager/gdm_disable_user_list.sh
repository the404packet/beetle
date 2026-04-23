#!/usr/bin/env bash
NAME="ensure GDM disable-user-list option is enabled"
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }
gdm_installed || { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

mkdir -p "$GD_db_dir"
drop_file="${GD_db_dir}/00-login-screen"

grep -q '\[org/gnome/login-screen\]' "$drop_file" 2>/dev/null \
    && sed -i '/disable-user-list/d' "$drop_file" \
    && echo "disable-user-list=true" >> "$drop_file" \
    || printf '%s\n' "[org/gnome/login-screen]" "disable-user-list=true" > "$drop_file"

dconf update 2>/dev/null || true

grep -Prhsq '^\s*disable-user-list\s*=\s*true' "$GD_db_dir" 2>/dev/null \
    && echo -e "${GREEN}SUCCESS${RESET}" \
    || { echo -e "${RED}FAILED${RESET}"; exit 1; }
exit 0