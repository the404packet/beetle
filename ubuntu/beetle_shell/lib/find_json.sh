#!/usr/bin/env bash

CONFIG_DIR="/etc/beetle"

find_module_json() {
    local script_path="$1"
    local rel_path="${script_path#$BEETLE_SHELL_ROOT/}"
    local json_type=""
    local json_file=""

    if [[ "$rel_path" == audit/system_maintenance/* || "$rel_path" == audit/system_maintenance/*/* || "$rel_path" == harden/system_maintenance/* || "$rel_path" == harden/system_maintenance/*/* ]]; then
        json_type="system_maintenance"; json_file="$CONFIG_DIR/system_maintenance.json"
    elif [[ "$rel_path" == audit/network/* || "$rel_path" == harden/network/* ]]; then
        json_type="network"; json_file="$CONFIG_DIR/network.json"
    elif [[ "$rel_path" == audit/services/* || "$rel_path" == harden/services/* ]]; then
        json_type="services"; json_file="$CONFIG_DIR/services.json"
    elif [[ "$rel_path" == audit/access_control/* || "$rel_path" == harden/access_control/* ]]; then
        json_type="access_control"; json_file="$CONFIG_DIR/access_control.json"
    elif [[ "$rel_path" == audit/host_based_firewall/* || "$rel_path" == harden/host_based_firewall/* ]]; then
        json_type="host_based_firewall"; json_file="$CONFIG_DIR/host_based_firewall.json"
    elif [[ "$rel_path" == audit/logging_and_auditing/* || "$rel_path" == harden/logging_and_auditing/* ]]; then
        json_type="logging_and_auditing"; json_file="$CONFIG_DIR/logging_and_auditing.json"
    elif [[ "$rel_path" == audit/initial_setup/* || "$rel_path" == harden/initial_setup/* ]]; then
        json_type="initial_setup"; json_file="$CONFIG_DIR/initial_setup.json"
    else
        echo ""; return 0
    fi

    [ -f "$json_file" ] && echo "${json_type}::${json_file}" || echo ""
}

export -f find_module_json