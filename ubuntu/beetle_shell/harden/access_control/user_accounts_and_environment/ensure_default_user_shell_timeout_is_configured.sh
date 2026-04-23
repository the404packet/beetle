#!/usr/bin/env bash

NAME="ensure default user shell timeout is configured"
SEVERITY='basic'

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

[ -f "$SSH_RAM_STORE" ] && source "$SSH_RAM_STORE"

MAX_TMOUT="${UE_tmout_max:-900}"
TARGET_FILE="${UE_tmout_profile_d_file:-/etc/profile.d/50-systemwide_tmout.sh}"

BRC=""
[ -f /etc/bashrc ] && BRC="/etc/bashrc"

# Remove any existing TMOUT lines from all shell config files to avoid conflicts
for f in $BRC /etc/profile /etc/profile.d/*.sh; do
    [ -f "$f" ] || continue
    [ "$f" = "$TARGET_FILE" ] && continue   # we'll write this one fresh
    if grep -Pq '^\s*([^#]+\s+)?TMOUT=' "$f" 2>/dev/null; then
        sed -i -E 's|^\s*(([^#]+\s+)?TMOUT=.*)$|# \1  # commented out by beetle|g' "$f"
    fi
    if grep -Pq '^\s*([^#]+;\s*)?readonly\s+TMOUT(\s|;|$|=)' "$f" 2>/dev/null; then
        sed -i -E 's|^\s*(([^#]+;\s*)?readonly\s+TMOUT(\s|;|$|=).*)$|# \1  # commented out by beetle|g' "$f"
    fi
    if grep -Pq '^\s*([^#]+;\s*)?export\s+TMOUT(\s|;|$|=)' "$f" 2>/dev/null; then
        sed -i -E 's|^\s*(([^#]+;\s*)?export\s+TMOUT(\s|;|$|=).*)$|# \1  # commented out by beetle|g' "$f"
    fi
done

# Write the canonical TMOUT configuration
mkdir -p "$(dirname "$TARGET_FILE")"
cat > "$TARGET_FILE" <<EOF
# Managed by beetle — CIS 5.4.3.2
TMOUT=${MAX_TMOUT}
readonly TMOUT
export TMOUT
EOF
chmod 644 "$TARGET_FILE"

# Validate
output1=""
output2=""

for f in $BRC /etc/profile /etc/profile.d/*.sh; do
    [ -f "$f" ] || continue
    if grep -Pq "^\s*([^#]+\s+)?TMOUT=($MAX_TMOUT|[1-8][0-9][0-9]|[1-9][0-9]|[1-9])\b" "$f" \
    && grep -Pq '^\s*([^#]+;\s*)?readonly\s+TMOUT(\s+|\s*;|\s*$|=[0-9]+)\b' "$f" \
    && grep -Pq '^\s*([^#]+;\s*)?export\s+TMOUT(\s+|\s*;|\s*$|=[0-9]+)\b' "$f"; then
        output1="$f"
    fi
done

for f in /etc/profile /etc/profile.d/*.sh $BRC; do
    [ -f "$f" ] || continue
    grep -Pq "^\s*([^#]+\s+)?TMOUT=(9[0-9][1-9]|9[1-9][0-9]|0+|[1-9]\d{3,})\b" "$f" && output2="$f"
done

if [[ -n "$output1" && -z "$output2" ]]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
else
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi
