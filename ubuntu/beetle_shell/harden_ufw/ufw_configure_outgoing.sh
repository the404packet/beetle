#!/bin/bash


NAME="ufw-configure-outgoing deny outgoing allow default certain ports"
SEVERITY="basic" # if not basic i will give it name as 'placeholder' so i know to change

RED="\e[37;41m"
GREEN="\e[37;42m"
RESET="\e[0m"

# Default ports
default_ports=(
  53/tcp 53/udp
  80/tcp 443/tcp
  123/udp
  853/tcp
  22/tcp 9418/tcp 873/tcp 2376/tcp
  8772/udp 4789/udp
)

# Function to allow ports
allow_ports() {
  for port in "$@"; do
    echo "Allowing port: $port"
    ufw allow out $port
  done
}

# Function to exclude ports
exclude_ports() {
  for port in "$@"; do
    echo "Excluding port: $port"
    ufw delete allow out $port
  done
}

# Parse arguments for additional include or exclude options
while getopts "i:ex:" opt; do
  case $opt in
    i) # Include extra ports
      include_ports+=($OPTARG)
      ;;
    ex) # Exclude specific ports
      exclude_ports+=($OPTARG)
      ;;
    *)
      echo "Invalid option: -$opt"
      exit 1
      ;;
  esac
done

# Apply the default ports
echo "Allowing default ports..."
allow_ports "${default_ports[@]}"

# Apply additional include ports
if [ ${#include_ports[@]} -gt 0 ]; then
  echo "Including extra ports: ${include_ports[@]}"
  allow_ports "${include_ports[@]}"
fi

# Apply exclude ports
if [ ${#exclude_ports[@]} -gt 0 ]; then
  echo "Excluding ports: ${exclude_ports[@]}"
  exclude_ports "${exclude_ports[@]}"
fi

# Set default policies at the end
ufw default deny outgoing  # Deny all outgoing by default
ufw reload

# ufw status verbose

