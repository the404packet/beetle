#!/usr/bin/env bash
set -uo pipefail

CONFIG_FILE="/etc/beetle/beetle.conf"

LOG_FILE=$(grep "^AUDIT_LOG_FILE=" "$CONFIG_FILE" 2>/dev/null | cut -d '=' -f2 | xargs || true)

if [[ -z "${LOG_FILE:-}" || ! -f "$LOG_FILE" ]]; then
    echo "Log file not found: $LOG_FILE"
    exit 1
fi

CURRENT_USER=$(whoami)

show_help() {
    echo "Usage: beetle logs [options]"
    echo ""
    echo "Options:"
    echo "  --since <time>        Filter logs (10d, 5h, 30m, 20s)"
    echo "  --type <command>      Filter by command"
    echo "  --user <username>     Filter by user"
    echo "  --help                Show this help"
}

parse_time() {
    local input="$1"
    local value="${input::-1}"
    local unit="${input: -1}"
    local seconds=0

    case "$unit" in
        d) seconds=$((value * 86400)) ;;
        h) seconds=$((value * 3600)) ;;
        m) seconds=$((value * 60)) ;;
        s) seconds=$((value)) ;;
        *) echo "Invalid time format"; exit 1 ;;
    esac

    date -d "-$seconds seconds" "+%Y-%m-%d %H:%M:%S"
}

since_time=""
type_filter=""
user_filter=""

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

filtered_logs=$(<"$LOG_FILE")

# ---------- TIME FILTER ----------
if [[ -n "$since_time" ]]; then
    filtered_logs=$(awk -v since="$since_time" '
    function to_epoch(ts) {
        gsub(/[-:]/, " ", ts)
        return mktime(ts)
    }
    BEGIN {
        split(since, s, "[- :]")
        since_epoch = mktime(s[1]" "s[2]" "s[3]" "s[4]" "s[5]" "s[6])
    }
    {
        timestamp = $1 " " $2
        split(timestamp, t, "[- :]")
        log_epoch = mktime(t[1]" "t[2]" "t[3]" "t[4]" "t[5]" "t[6])

        if (log_epoch >= since_epoch)
            print
    }' <<< "$filtered_logs" || true)
fi

# ---------- TYPE FILTER ----------
if [[ -n "$type_filter" ]]; then
    filtered_logs=$(grep -E "cmd=\".*$type_filter.*\"" <<< "$filtered_logs" || true)
fi

# ---------- USER FILTER ----------
if [[ -n "$user_filter" ]]; then
    filtered_logs=$(grep "user=$user_filter" <<< "$filtered_logs" || true)
fi

if [[ -z "$filtered_logs" ]]; then
    echo "No logs found"
    exit 0
fi

# ---------- HEADER ----------
printf "%-19s | %-6s | %-10s | %-10s | %-8s | %-6s | %s\n" \
"TIMESTAMP" "PID" "USER" "STATUS" "TIME" "ID" "COMMAND"

printf "%s\n" "------------------------------------------------------------------------------------------------------"

# ---------- OUTPUT (NO WRAP) ----------
echo "$filtered_logs" | awk '
{
    ts = $1 " " $2

    match($0, /pid=([^ ]+)/, p); pid = p[1]
    match($0, /user=([^ ]+)/, u); user = u[1]
    match($0, /status=([^ ]+)/, s); status = s[1]
    match($0, /time=([^ ]+)/, t); time = t[1]
    match($0, /id=([^ ]+)/, i); id = substr(i[1], length(i[1])-5)
    match($0, /cmd="([^"]*)"/, c); cmd = c[1]

    printf "%-19s | %-6s | %-10s | %-10s | %-8s | %-6s | %s\n", \
    ts, pid, user, status, time, id, cmd
}
'