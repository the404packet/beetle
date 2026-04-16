#!/usr/bin/env bash

NAME="ensure telnet and inetutils-telnet are not installed"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if telnet packages are installed
if dpkg-query -l | grep -E '^(ii)\s+(telnet|inetutils-telnet)\b' &>/dev/null; then
    output="telnet or inetutils-telnet is installed"
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0