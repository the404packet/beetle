#!/usr/bin/env bash
# beetle_prompt.sh - Prompt helper for Beetle hardening framework

beetle_prompt() {
    local prompt="$1"
    local default="${2:-y}"
    local response=""

    # --- Mode 1: Running under beetled daemon (fd 4 = answer_pipe) ---
    if [ -e "/proc/self/fd/4" ] || [ "${BEETLE_INTERACTIVE:-0}" = "1" ]; then
        # Print PROMPT: and immediately flush stdout buffer so beetled sees it over the socket
        printf 'PROMPT:%s\n' "$prompt" >&2

        # Block waiting for answer on File Descriptor 4
        if read -r response <&4; then
            response="${response#ANSWER:}"
            response="${response,,}"
            case "$response" in
                y|yes) echo "y"; return 0 ;;
                n|no)  echo "n"; return 0 ;;
                *)     echo "$default"; return 0 ;;
            esac
        fi


        # If fd 4 reaches EOF (client disconnected)
        echo "$default"
        return 0
    fi

    # --- Mode 2: Standalone terminal execution ---
    if [ -t 0 ] && [ -c /dev/tty ]; then
        while true; do
            printf '%s [y/n] (default: %s): ' "$prompt" "$default" >&2
            if ! read -r response </dev/tty; then
                echo "$default"
                return 0
            fi
            response="${response,,}"
            case "$response" in
                y|yes) echo "y"; return 0 ;;
                n|no)  echo "n"; return 0 ;;
                "")    echo "$default"; return 0 ;;
                *)     echo "Please answer y or n." >&2 ;;
            esac
        done
    fi

    # --- Mode 3: Non-interactive fallback ---
    echo "$default"
    return 0
}