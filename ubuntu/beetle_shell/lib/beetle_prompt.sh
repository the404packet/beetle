#!/usr/bin/env bash
# beetle_prompt.sh - Prompt helper that works in three contexts:
#   1. Under beetled daemon (fd 3/4 pipes to client)  -> relay prompt over socket
#   2. Standalone in a terminal                        -> prompt at tty
#   3. Non-interactive (tests, cron)                   -> return default
#
# Requires nothing from the caller. Safe to source anywhere.

# beetle_prompt <prompt-text> <default: y|n>
# Outputs the user's answer on stdout: "y" or "n"
beetle_prompt() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    # --- Mode 1: running under beetled (fd 3 = prompts out, fd 4 = answers in)
    if [ -e "/proc/self/fd/3" ] && [ -e "/proc/self/fd/4" ]; then
        # Emit the prompt on the control channel
        printf 'PROMPT:%s\n' "$prompt" >&3
        # Block for the answer
        if read -r response <&4; then
            response="${response,,}"
            case "$response" in
                y|yes) echo "y"; return 0 ;;
                n|no)  echo "n"; return 0 ;;
                "")    echo "$default"; return 0 ;;
                *)     echo "$default"; return 0 ;;
            esac
        fi
        # fd 4 closed → client went away → use default
        echo "$default"
        return 0
    fi

    # --- Mode 2: standalone with a real terminal
    if [ -t 0 ] && [ -c /dev/tty ]; then
        while true; do
            printf '%s [y/n] (default: %s): ' "$prompt" "$default"
            if ! read -r response </dev/tty; then
                # tty closed mid-prompt
                echo "$default"
                return 0
            fi
            response="${response:-$default}"
            response="${response,,}"
            case "$response" in
                y|yes) echo "y"; return 0 ;;
                n|no)  echo "n"; return 0 ;;
                *)     printf 'Please answer y or n.\n' >&2 ;;
            esac
        done
    fi

    # --- Mode 3: non-interactive, no daemon
    echo "$default"
    return 0
}