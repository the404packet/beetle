#!/usr/bin/env bash

NAME="ssh login banner"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

if ! is_package_installed "openssh-server"; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

BANNER_FILE="/etc/issue.net"
SSHD_CONFIG="/etc/ssh/sshd_config"
flag=1

# Write a safe banner that discloses no OS info
cat > "$BANNER_FILE" <<'EOF'
Authorized access only. All activity may be monitored and reported.
EOF
chmod 644 "$BANNER_FILE"

# Set Banner directive in sshd_config (add or replace)
if grep -Piq '^\s*Banner\b' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i "s|^\s*[Bb]anner\s.*|Banner $BANNER_FILE|" "$SSHD_CONFIG"
else
    echo "Banner $BANNER_FILE" >> "$SSHD_CONFIG"
fi

# Apply to drop-ins as well
if [[ -d /etc/ssh/sshd_config.d ]]; then
    while IFS= read -r -d $'\0' file; do
        if grep -Piq '^\s*Banner\b' "$file" 2>/dev/null; then
            sed -i "s|^\s*[Bb]anner\s.*|Banner $BANNER_FILE|" "$file"
        fi
    done < <(find /etc/ssh/sshd_config.d -type f -name "*.conf" -print0)
fi

# Validate
banner_set=$(sshd -T 2>/dev/null | awk '$1=="banner"{print $2}')
if [[ "$banner_set" == "$BANNER_FILE" && -f "$BANNER_FILE" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

exit 0
