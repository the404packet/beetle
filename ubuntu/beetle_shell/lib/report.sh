#!/usr/bin/env bash
# report.sh — PDF report generation for Beetle audit/harden runs
#
# Usage:
#   report_init <mode> <severity> [snapshot_id]
#   report_add <relative_path> <name> <result>
#   report_finalize
#
# Reports are written to /var/lib/beetle/reports/

REPORT_DIR="/var/lib/beetle/reports"
REPORT_TMP=""

_report_ts() { date -u +"%Y-%m-%d %H:%M:%S UTC"; }

_report_titlecase() {
    local s="$1"
    s="${s//_/ }"
    s="${s//-/ }"
    local out=""
    local word
    for word in $s; do
        out+="$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1} "
    done
    printf '%s' "${out% }"
}

_report_html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    printf '%s' "$s"
}

report_init() {
    REPORT_MODE="$1"
    REPORT_SEVERITY="$2"
    REPORT_SNAPSHOT="${3:-}"
    REPORT_STARTED="$(_report_ts)"
    REPORT_FINISHED=""
    REPORT_TMP="$(mktemp -d -t beetle-report-XXXXXX)"
    : > "$REPORT_TMP/results.tsv"
}

report_add() {
    [ -z "$REPORT_TMP" ] && return 0

    # Strip ANSI escape codes from result (scripts emit colored output)
    local result="$3"
    result=$(printf '%s' "$result" | sed 's/\x1b\[[0-9;]*m//g')

    printf '%s\t%s\t%s\n' "$1" "$2" "$result" >> "$REPORT_TMP/results.tsv"
}

_report_emit_section_headers() {
    local dir_path="$1"
    local last="$2"

    [ -z "$dir_path" ] && return 0

    local -a dirs_cur dirs_last
    IFS='/' read -ra dirs_cur <<< "$dir_path"
    IFS='/' read -ra dirs_last <<< "$last"

    local common=0
    local n_cur=${#dirs_cur[@]}
    local n_last=${#dirs_last[@]}
    local max_common=$(( n_cur < n_last ? n_cur : n_last ))
    while [ $common -lt $max_common ] && \
          [ "${dirs_cur[$common]}" = "${dirs_last[$common]}" ]; do
        common=$(( common + 1 ))
    done

    local i
    for ((i=common; i<n_cur; i++)); do
        printf '<tr class="section"><td colspan="3" style="padding-left: %dpx">%s</td></tr>\n' \
            $(( i * 20 + 5 )) "$(_report_titlecase "${dirs_cur[$i]}")"
    done
}

report_finalize() {
    [ -z "$REPORT_TMP" ] && return 0

    REPORT_FINISHED="$(_report_ts)"
    mkdir -p "$REPORT_DIR"

    local ts pdf_path html_path
    ts=$(date -u +"%Y%m%d_%H%M%S")
    pdf_path="$REPORT_DIR/${REPORT_MODE}_${REPORT_SEVERITY,,}_${ts}.pdf"
    html_path="$REPORT_TMP/report.html"

    # Header
    {
        echo '<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
        echo 'body{font-family:DejaVu Sans,sans-serif;font-size:11pt;margin:2em}'
        echo 'h1{text-align:center;font-size:22pt;margin-bottom:.2em}'
        echo '.meta{border:2px solid #333;padding:1em;margin:2em auto;width:70%}'
        echo '.meta table{width:100%}.meta td{padding:.3em .5em}'
        echo '.meta td.lbl{font-weight:bold;width:30%}'
        echo 'table.results{width:100%;border-collapse:collapse;margin-top:2em}'
        echo 'table.results th{background:#f0f0f0;border-bottom:2px solid #333;padding:.5em;text-align:left}'
        echo 'table.results th.yn{text-align:center;width:6em}'
        echo 'table.results td{padding:.3em .5em;border-bottom:1px solid #ddd;vertical-align:top}'
        echo 'table.results td.yn{text-align:center;font-size:14pt}'
        echo 'tr.section td{background:#fafafa;font-weight:bold;padding-top:.6em}'
        echo '.footer{margin-top:3em;padding-top:1em;border-top:1px solid #999;text-align:center;color:#666;font-size:9pt}'
        echo '</style></head><body>'
        echo "<h1>BEETLE ${REPORT_MODE^^} REPORT</h1>"
        echo '<div class="meta"><table>'
        echo "  <tr><td class=\"lbl\">Mode</td><td>$(_report_html_escape "$REPORT_MODE")</td></tr>"
        echo "  <tr><td class=\"lbl\">Severity</td><td>$(_report_html_escape "$REPORT_SEVERITY")</td></tr>"
        if [ -n "$REPORT_SNAPSHOT" ]; then
            echo "  <tr><td class=\"lbl\">Snapshot</td><td>$(_report_html_escape "$REPORT_SNAPSHOT")</td></tr>"
        fi
        echo "  <tr><td class=\"lbl\">Started</td><td>$(_report_html_escape "$REPORT_STARTED")</td></tr>"
        echo "  <tr><td class=\"lbl\">Finished</td><td>$(_report_html_escape "$REPORT_FINISHED")</td></tr>"
        echo '</table></div>'
        echo '<table class="results">'
        echo '<tr><th>Check</th><th class="yn">Yes</th><th class="yn">No</th></tr>'
    } > "$html_path"

    # Body rows
    local last_dir_path=""
    local path name result
    while IFS=$'\t' read -r path name result; do
        # Strip .sh suffix
        path="${path%.sh}"
        local dir_path="${path%/*}"
        [ "$dir_path" = "$path" ] && dir_path=""

        if [ "$dir_path" != "$last_dir_path" ]; then
            _report_emit_section_headers "$dir_path" "$last_dir_path" >> "$html_path"
            last_dir_path="$dir_path"
        fi

        local y="&#9744;" no="&#9745;"
        case "${result,,}" in
            hardened|success) y="&#9745;"; no="&#9744;" ;;
        esac
        local indent=$(( ($(echo "$dir_path" | tr -cd '/' | wc -c) + 1) * 20 ))
        printf '<tr><td style="padding-left: %dpx">%s</td><td class="yn">%s</td><td class="yn">%s</td></tr>\n' \
            "$indent" "$(_report_html_escape "$name")" "$y" "$no" >> "$html_path"
    done < <(sort -t$'\t' -k1,1 "$REPORT_TMP/results.tsv")

    # Footer
    {
        echo '</table>'
        echo '<div class="footer">'
        echo 'Generated using Beetle — an automated CIS hardening tool'
        echo '</div>'
        echo '</body></html>'
    } >> "$html_path"

    # PDF conversion — install wkhtmltopdf on demand if missing
    if ! command -v wkhtmltopdf >/dev/null 2>&1; then
        echo ""
        echo "📥 Installing wkhtmltopdf for PDF report generation..."
        if command -v apt-get >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q wkhtmltopdf </dev/null >/dev/null 2>&1 || true
        fi
    fi

    if command -v wkhtmltopdf >/dev/null 2>&1; then
        wkhtmltopdf --quiet --encoding utf-8 "$html_path" "$pdf_path" 2>/dev/null
        if [ -f "$pdf_path" ]; then
            echo ""
            echo "📄 Report generated: $pdf_path"
        else
            echo ""
            echo "⚠️  PDF generation failed (HTML kept at $html_path)"
        fi
    else
        echo ""
        echo "⚠️  wkhtmltopdf not available — PDF skipped"
        echo "    HTML kept at: $html_path"
    fi

    rm -rf "$REPORT_TMP"
    REPORT_TMP=""
}

export -f report_init report_add report_finalize
export -f _report_html_escape _report_titlecase _report_ts
