#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="/var/log/beetle.log"

# ---------- HELP ----------
show_help() {
    echo "Usage: beetle logs [options]"
    echo ""
    echo "Options:"
    echo "  --since <time>        Filter logs (e.g., 10d, 5h, 30m, 20s)"
    echo "  --type <category>     Filter by type (snapshot, audit, system)"
    echo "  --user <username>     Filter by user"
    echo "  --summary             Show success/failure counts"
    echo "  --help                Show this help"
}

# ---------- PARSE TIME ----------
parse_time() {
    local input="$1"

    local value unit seconds=0

    value="${input::-1}"
    unit="${input: -1}"

    case "$unit" in
        d) seconds=$((value * 86400)) ;;
        h) seconds=$((value * 3600)) ;;
        m) seconds=$((value * 60)) ;;
        s) seconds=$((value)) ;;
        *) echo "Invalid time format"; exit 1 ;;
    esac

    date -d "-$seconds seconds" "+%Y-%m-%d %H:%M:%S"
}

# ---------- FILTER LOGS ----------
since_time=""
type_filter=""
user_filter=""
summary=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since)
            since_time=$(parse_time "$2")
            shift 2
            ;;
        --type)
            type_filter="$2"
            shift 2
            ;;
        --user)
            user_filter="$2"
            shift 2
            ;;
        --summary)
            summary=true
            shift
            ;;
        --help|"")
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ---------- READ LOGS ----------
filtered_logs=$(cat "$LOG_FILE")

# ---------- APPLY TIME FILTER ----------
if [[ -n "$since_time" ]]; then
    filtered_logs=$(awk -v since="$since_time" '
    {
        timestamp = $1 " " $2
        if (timestamp >= since)
            print
    }' <<< "$filtered_logs")
fi

# ---------- APPLY TYPE FILTER ----------
if [[ -n "$type_filter" ]]; then
    case "$type_filter" in
        snapshot)
            filtered_logs=$(grep 'cmd="snapshot' <<< "$filtered_logs" || true)
            ;;
        audit)
            filtered_logs=$(grep -E 'status=FAIL|status=SUCCESS' <<< "$filtered_logs" || true)
            ;;
        system)
            filtered_logs=$(grep 'cmd="system' <<< "$filtered_logs" || true)
            ;;
        *)
            echo "Unknown type: $type_filter"
            exit 1
            ;;
    esac
fi

# ---------- APPLY USER FILTER ----------
if [[ -n "$user_filter" ]]; then
    filtered_logs=$(grep "user=$user_filter" <<< "$filtered_logs" || true)
fi

# ---------- SUMMARY ----------
if [[ "$summary" = true ]]; then
    success_count=$(grep -c "status=SUCCESS" <<< "$filtered_logs" || true)
    fail_count=$(grep -c "status=FAIL" <<< "$filtered_logs" || true)

    echo "Summary:"
    echo "  SUCCESS: $success_count"
    echo "  FAIL:    $fail_count"
    exit 0
fi

# ---------- OUTPUT ----------
if [[ -z "$filtered_logs" ]]; then
    echo "No logs found"
else
    echo "$filtered_logs"
fi