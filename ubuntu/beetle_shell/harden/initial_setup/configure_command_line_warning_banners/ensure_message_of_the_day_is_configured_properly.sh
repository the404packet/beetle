#!/usr/bin/env bash
NAME='ensure message of the day is configured properly'
GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
[ -f "$INITIAL_SETUP_RAM_STORE" ] && source "$INITIAL_SETUP_RAM_STORE"

[ ! -e /etc/motd ] && { echo -e "${GREEN}SUCCESS${RESET}"; exit 0; }

os_id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | sed 's/"//g')
pattern="(\\\\v|\\\\r|\\\\m|\\\\s|${os_id})"

if grep -Ei "$pattern" /etc/motd 2>/dev/null | grep -q .; then
    cat >&2 <<'EOF'
MANUAL ACTION REQUIRED — /etc/motd contains OS-identifying information.
Remove any instances of \m \r \s \v or the OS name, OR remove the file:
  rm /etc/motd
EOF
    echo -e "${RED}FAILED${RESET}"; exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"; exit 0