#!/usr/bin/env bash
# order.sh — ordered script discovery for Beetle
#
# If $base/.order exists, it drives execution order.
# Otherwise, falls back to alphabetical find|sort.
#
# Usage:
#   mapfile -t scripts < <(ordered_scripts "$SEARCH_PATH")

ordered_scripts() {
    local base="$1"

    if [ -f "$base/.order" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            # strip leading whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            # strip comments
            line="${line%%#*}"
            # strip trailing whitespace
            line="${line%"${line##*[![:space:]]}"}"
            [ -z "$line" ] && continue

            local full="$base/$line"
            if [ -f "$full" ]; then
                echo "$full"
            else
                echo "WARN: .order references missing file: $line" >&2
            fi
        done < "$base/.order"
        return 0
    fi

    find "$base" -mindepth 1 -type f -name '*.sh' | sort
}
