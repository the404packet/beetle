#!/usr/bin/env bash

CONFIG_DIR="/etc/beetle"

find_module_json() {
    local script_path="$1"
    local rel_path="${script_path#$BEETLE_SHELL_ROOT/}"
    local json_type=""
    local json_file=""

    case "$rel_path" in
        audit/system_maintenance/*|harden/system_maintenance/*)
            json_type="system_maintenance"
            json_file="$CONFIG_DIR/system_maintenance.json"
            ;;
        audit/network/*|harden/network/*)
            json_type="network"
            json_file="$CONFIG_DIR/network.json"
            ;;
        audit/services/*|harden/services/*)
            json_type="services"
            json_file="$CONFIG_DIR/services.json"
            ;;
        audit/access_control/*|harden/access_control/*)
            json_type="access_control"
            json_file="$CONFIG_DIR/access_control.json"
            ;;
        audit/host_based_firewall/*|harden/host_based_firewall/*)
            json_type="host_based_firewall"
            json_file="$CONFIG_DIR/host_based_firewall.json"
            ;;
        *)
            # No JSON needed for this module
            echo ""
            return 0
            ;;
    esac

    if [ -f "$json_file" ]; then
        # Return "type::path" — audit.sh splits on :: to get both pieces
        echo "${json_type}::${json_file}"
    else
        echo ""
    fi
}

export -f find_module_json