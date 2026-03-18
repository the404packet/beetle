#!/usr/bin/env bash

NAME="Ensure at access control files are properly configured"
SEVERITY="medium"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

fail_reasons=()

# Check if at is installed
if ! dpkg-query -s at &>/dev/null; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

# -----------------------------
# Check /etc/at.allow
# -----------------------------
if [[ ! -e /etc/at.allow ]]; then
    fail_reasons+=("/etc/at.allow does not exist")
else
    mode=$(stat -Lc '%a' /etc/at.allow)
    owner=$(stat -Lc '%U' /etc/at.allow)
    group=$(stat -Lc '%G' /etc/at.allow)

    if (( mode > 640 )); then
        fail_reasons+=("/etc/at.allow has mode $mode (should be 640 or more restrictive)")
    fi

    [[ "$owner" != "root" ]] && \
        fail_reasons+=("/etc/at.allow owner is $owner (should be root)")

    if [[ "$group" != "root" && "$group" != "daemon" ]]; then
        fail_reasons+=("/etc/at.allow group is $group (should be root or daemon)")
    fi
fi

# -----------------------------
# Check /etc/at.deny
# -----------------------------
if [[ -e /etc/at.deny ]]; then
    mode=$(stat -Lc '%a' /etc/at.deny)
    owner=$(stat -Lc '%U' /etc/at.deny)
    group=$(stat -Lc '%G' /etc/at.deny)

    if (( mode > 640 )); then
        fail_reasons+=("/etc/at.deny has mode $mode (should be 640 or more restrictive)")
    fi

    [[ "$owner" != "root" ]] && \
        fail_reasons+=("/etc/at.deny owner is $owner (should be root)")

    if [[ "$group" != "root" && "$group" != "daemon" ]]; then
        fail_reasons+=("/etc/at.deny group is $group (should be root or daemon)")
    fi
fi

# -----------------------------
# Final Result
# -----------------------------
if [[ ${#fail_reasons[@]} -eq 0 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    for reason in "${fail_reasons[@]}"; do
        echo "$reason"
    done
fi

exit 0