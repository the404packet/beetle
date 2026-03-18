#!/bin/bash

show_general_help() {
cat << "EOF"
Usage:
  beetle <command> [folder] [severity]

Core Commands:
  banner
  audit
  harden
  version
  help

Description:
  banner    Display Beetle ASCII banner
  audit     Run system audit checks
  harden    Apply remediation scripts
  version   Show Beetle version
  help      Show help information

Severity Levels:
  basic
  moderate
  strong

EOF
}

show_command_help() {
    case "$1" in
        banner)
            cat << "EOF"
Usage:
  beetle banner

Description:
  Displays the Beetle ASCII banner.
EOF
            ;;
        audit)
            cat << "EOF"
Usage:
  beetle audit [folder] [severity]

Description:
  Runs system audit checks.
EOF
            ;;
        harden)
            cat << "EOF"
Usage:
  beetle harden [folder] [severity]

Description:
  Applies remediation scripts.
EOF
            ;;
        version)
            cat << "EOF"
Usage:
  beetle version

Description:
  Displays current Beetle version.
EOF
            ;;
        *)
            echo "Unknown command: $1"
            ;;
    esac
}

if [[ -z "$1" ]]; then
    show_general_help
elif [[ "$1" == "help" && -n "$2" ]]; then
    show_command_help "$2"
elif [[ "$1" == "help" ]]; then
    show_general_help
else
    show_general_help
fi
