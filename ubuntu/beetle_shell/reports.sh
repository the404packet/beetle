#!/usr/bin/env bash
# reports.sh — manage Beetle PDF reports
#
# Usage:
#   beetle reports ls [audit|harden]      list reports
#   beetle reports rm <name|id>           delete a report
#   beetle reports size                   show total storage usage
#   beetle reports latest [audit|harden]  print path to newest report
#   beetle reports path                   print reports directory

REPORT_DIR="/var/lib/beetle/reports"

# ---------- HELP ----------
show_help() {
    echo "Usage:"
    echo "  beetle reports ls [audit|harden]      List reports"
    echo "  beetle reports rm <name|id>           Delete a report"
    echo "  beetle reports size                   Show storage usage"
    echo "  beetle reports latest [audit|harden]  Print newest report path"
    echo "  beetle reports path                   Print reports directory"
}

# ---------- ARGS ----------
if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR"
fi

case "${1:-}" in
    ls)
        FILTER="${2:-}"
        printf "\n%-45s | %-10s | %-10s | %s\n" "REPORT NAME" "MODE" "SEVERITY" "SIZE"
        printf -- "-------------------------------------------------------------------------------------------\n"

        found=0
        # Report names look like: <mode>_<severity>_<YYYYMMDD>_<HHMMSS>.pdf
        for f in "$REPORT_DIR"/*.pdf; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            # Parse: mode_severity_YYYYMMDD_HHMMSS.pdf
            base="${name%.pdf}"
            mode="${base%%_*}"
            rest="${base#*_}"
            severity="${rest%%_*}"

            if [ -n "$FILTER" ] && [ "$mode" != "$FILTER" ]; then
                continue
            fi

            size=$(stat -c '%s' "$f" 2>/dev/null)
            size_h=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")

            printf "%-45s | %-10s | %-10s | %s\n" "$name" "$mode" "$severity" "$size_h"
            found=$((found + 1))
        done

        if [ "$found" -eq 0 ]; then
            echo "  (no reports found)"
        fi
        echo ""
        ;;

    rm)
        INPUT="${2:-}"
        if [ -z "$INPUT" ]; then
            echo "[!] Usage: beetle reports rm <name|id>"
            exit 1
        fi

        # Match exact name or substring
        MATCH=""
        for f in "$REPORT_DIR"/*.pdf; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            if [ "$name" = "$INPUT" ] || [ "$name" = "${INPUT}.pdf" ]; then
                MATCH="$f"
                break
            fi
            if [[ "$name" == *"$INPUT"* ]]; then
                MATCH="$f"
                # don't break — take last if multiple, matches "latest behaviour"
            fi
        done

        if [ -z "$MATCH" ]; then
            echo "[!] No report found for: $INPUT"
            exit 1
        fi

        rm -f "$MATCH"
        echo "[+] Removed report: $(basename "$MATCH")"
        ;;

    size)
        total_files=$(find "$REPORT_DIR" -maxdepth 1 -type f -name '*.pdf' 2>/dev/null | wc -l)
        total_size=$(du -sh "$REPORT_DIR" 2>/dev/null | cut -f1)
        audit_files=$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'audit_*.pdf' 2>/dev/null | wc -l)
        harden_files=$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'harden_*.pdf' 2>/dev/null | wc -l)

        echo ""
        echo "Report Storage Usage:"
        echo "  Path          : $REPORT_DIR"
        echo "  Total Size    : $total_size  ($total_files reports)"
        echo "  Audit reports : $audit_files"
        echo "  Harden reports: $harden_files"
        echo ""
        ;;

    latest)
        FILTER="${2:-}"
        latest=""
        for f in "$REPORT_DIR"/*.pdf; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            mode="${name%%_*}"
            if [ -n "$FILTER" ] && [ "$mode" != "$FILTER" ]; then
                continue
            fi
            if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then
                latest="$f"
            fi
        done

        if [ -z "$latest" ]; then
            echo "[!] No reports found"
            exit 1
        fi
        echo "$latest"
        ;;

    path)
        echo "$REPORT_DIR"
        ;;

    ""|help|--help|-h)
        show_help
        ;;

    *)
        echo "[!] Unknown subcommand: $1"
        show_help
        exit 1
        ;;
esac
