#!/usr/bin/env bash

NAME="Ensure apache2 and nginx are not installed or services are disabled"
SEVERITY="basic"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

output=""

# Check if either web server package is installed
apache_installed=false
nginx_installed=false

if dpkg-query -s apache2 &>/dev/null; then
    apache_installed=true
fi

if dpkg-query -s nginx &>/dev/null; then
    nginx_installed=true
fi

# If any package is installed, check services
if [[ "$apache_installed" == true || "$nginx_installed" == true ]]; then

    enabled=$(systemctl is-enabled apache2.socket apache2.service nginx.service 2>/dev/null | grep enabled)
    active=$(systemctl is-active apache2.socket apache2.service nginx.service 2>/dev/null | grep '^active')

    if [[ -n "$enabled" ]] || [[ -n "$active" ]]; then
        output="apache2/nginx installed and one or more services are enabled/active"
    fi
fi

if [[ -z "$output" ]]; then
    echo -e "${GREEN}HARDENED${RESET}"
else
    echo -e "${RED}NOT HARDENED${RESET}"
    echo "$output"
fi

exit 0
