#!/usr/bin/env bash
NAME='ensure bootloader password is set'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

# Cannot automate password generation — requires interactive input.
# Check if already configured; if not, print instructions and fail.
flag=1
grep -Pq '^\s*set superusers=' "$BL_grub_cfg" 2>/dev/null || flag=0
awk -F. '/^\s*password/ {print $1"."$2"."$3}' "$BL_grub_cfg" 2>/dev/null \
    | grep -Pq 'password_pbkdf2\s+\S+\s+grub\.pbkdf2\.sha512' || flag=0

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"; exit 0
fi

cat >&2 <<'EOF'
MANUAL ACTION REQUIRED — bootloader password not set.
Steps:
  1. grub-mkpasswd-pbkdf2 --iteration-count=600000 --salt=64
  2. Add to /etc/grub.d/40_custom (do NOT use 00_header):
       set superusers="grub_admin"
       password_pbkdf2 grub_admin <hash>
  3. update-grub
  Optional (allow boot without password):
     Edit /etc/grub.d/10_linux, add --unrestricted to CLASS=
EOF
echo -e "${RED}FAILED${RESET}"; exit 1