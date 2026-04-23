#!/usr/bin/env bash

NAME="ensure sshd client alive interval and count max are configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

INTERVAL_MIN="${SSHD_CLIENTALIVEINTERVAL_MIN:-1}"
COUNTMAX_MIN="${SSHD_CLIENTALIVECOUNTMAX_MIN:-1}"

# Use the minimum valid values as the hardened values
TARGET_INTERVAL="${SSHD_CLIENTALIVEINTERVAL_VALUE:-300}"
TARGET_COUNTMAX="${SSHD_CLIENTALIVECOUNTMAX_VALUE:-3}"

SSHD_CONFIG="/etc/ssh/sshd_config"
flag=1

set_directive() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -Piq "^\s*${key}\b" "$file" 2>/dev/null; then
        sed -i "s|^\s*[Cc]lient[Aa]live${key#clientalive}\s.*|${key} ${value}|I" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
}

set_directive "$SSHD_CONFIG" "ClientAliveInterval" "$TARGET_INTERVAL"
set_directive "$SSHD_CONFIG" "ClientAliveCountMax" "$TARGET_COUNTMAX"

if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*ClientAliveInterval\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Cc]lient[Aa]live[Ii]nterval\s.*|ClientAliveInterval $TARGET_INTERVAL|" "$file"
        fi
        if grep -Piq '^\s*ClientAliveCountMax\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Cc]lient[Aa]live[Cc]ount[Mm]ax\s.*|ClientAliveCountMax $TARGET_COUNTMAX|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
while read -r key value; do
    case "$key" in
        clientaliveinterval)  (( value >= INTERVAL_MIN )) || flag=0 ;;
        clientalivecountmax)  (( value >= COUNTMAX_MIN )) || flag=0 ;;
    esac
done < <(sshd -T 2>/dev/null | grep -Pi '(clientaliveinterval|clientalivecountmax)')

if (( flag )); then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
