#!/bin/bash

show_general_help() {
cat << "EOF"
Usage:
  beetle <command> [options]

Core Commands:
  banner              Show Beetle banner
  help                Show this help menu
  audit               Run audit checks
  version             Show version info

Help Options:
  beetle help
  beetle --help
  beetle -h

EOF
}

show_command_help() {
    case "$1" in
        banner)
            echo "Usage: beetle banner"
            echo "Description: Displays the Beetle ASCII banner."
            ;;
        audit)
            echo "Usage: beetle audit"
            echo "Description: Runs system audit checks."
            ;;
        version)
            echo "Usage: beetle version"
            echo "Description: Displays current Beetle version."
            ;;
        *)
            echo "Unknown command: $1"
            ;;
    esac
}

if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
    show_general_help
elif [[ "$1" == "help" ]]; then
    show_general_help
elif [[ "$#" -ge 1 ]]; then
    show_command_help "$1"
else
    show_general_help
fi
