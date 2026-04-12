#!/usr/bin/env bash

NAME="Ensure cron service is enabled and active"
SEVERITY="medium"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

fail_reasons=()

if ! dpkg-query -s cron &>/dev/null; then
    echo -e "${GREEN}HARDENED${RESET}"
    exit 0
fi

# Check if cron service is enabled
enabled=$(systemctl list-unit-files | awk '$1~/^crond?\.service/{print $2}')

if [[ "$enabled" != "enabled" ]]; then
    fail_reasons+=("cron service is not enabled")
fi

# Check if cron service is active
active=$(systemctl list-units | awk '$1~/^crond?\.service/{print $3}')

if [[ "$active" != "active" ]]; then
    fail_reasons+=("cron service is not active")
fi

# Final Result
if [[ ${#fail_reasons[@]} -eq 0 ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    for reason in "${fail_reasons[@]}"; do
        echo "$reason"
    done
fi

exit 0