#!/usr/bin/env bash

# ==============================================================================
# Master Unsecure Script: Executes all section unsecure scripts
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "----------------------------------------------------------------------"
echo "💥 Intentional Unsecuring of System Settings Initiated..."
echo "----------------------------------------------------------------------"

# Run category unsecure scripts
[ -f "$SCRIPT_DIR/system_maintenance/unsecure_system_maintenance.sh" ] && bash "$SCRIPT_DIR/system_maintenance/unsecure_system_maintenance.sh"

echo "----------------------------------------------------------------------"
echo "⚠️ System is now UNSECURED (Ready for Audit verification)"
echo "----------------------------------------------------------------------"
