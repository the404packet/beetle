#!/usr/bin/env bash

NAME="ensure SUID and SGID files are reviewed"

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

[ -f "$PERM_RAM_STORE" ] && source "$PERM_RAM_STORE" || { echo -e "${RED}FAILED${RESET}"; exit 1; }

count="$SS_count"
a_suspicious=()

for ((i=0; i<count; i++)); do
    n_var="SS_${i}_name"; name="${!n_var}"
    p_var="SS_${i}_path"; path="${!p_var}"
    r_var="SS_${i}_risk"; risk="${!r_var}"
    [ -f "$path" ] || continue

    mode=$(stat -Lc '%#a' "$path" 2>/dev/null)
    has_suid=$(( 8#$mode & 04000 ))
    has_sgid=$(( 8#$mode & 02000 ))
    [ "$has_suid" -eq 0 ] && [ "$has_sgid" -eq 0 ] && continue

    pkg=$(dpkg -S "$path" 2>/dev/null | awk -F: '{print $1}' | head -1)
    if [ -n "$pkg" ]; then
        if dpkg --verify "$pkg" 2>/dev/null | grep -q "^??5.*${path}"; then
            a_suspicious+=("CHECKSUM MISMATCH [$risk]: $path (pkg: $pkg)")
        fi
    else
        a_suspicious+=("NOT FROM PACKAGE [$risk]: $path")
    fi
done

if [ "${#a_suspicious[@]}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${RESET}"
    exit 0
fi

echo ""
echo -e "${CYAN}  Suspicious SUID/SGID binaries detected:${RESET}"
for entry in "${a_suspicious[@]}"; do
    echo "    $entry"
done
echo ""
echo -e "  Beetle recommends removing SUID/SGID bits from suspicious binaries above"
echo ""
echo -e "  Press ${GREEN}ENTER${RESET} to apply beetle recommended hardening"
echo -e "  Type   ${RED}no${RESET}   to skip and mark as failed"
read -r -p "  Choice: " response

if [[ "$response" == "no" ]]; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

failed=false
for entry in "${a_suspicious[@]}"; do
    path=$(echo "$entry" | grep -oP '(?<=: )/\S+(?= \(|$)')
    [ -f "$path" ] || continue
    chmod u-s,g-s "$path" 2>/dev/null

    mode=$(stat -Lc '%#a' "$path" 2>/dev/null)
    has_suid=$(( 8#$mode & 04000 ))
    has_sgid=$(( 8#$mode & 02000 ))
    if [ "$has_suid" -ne 0 ] || [ "$has_sgid" -ne 0 ]; then
        failed=true
    fi
done

if $failed; then
    echo -e "${RED}FAILED${RESET}"
    exit 1
fi

echo -e "${GREEN}SUCCESS${RESET}"
exit 0