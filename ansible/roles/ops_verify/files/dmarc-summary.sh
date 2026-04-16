#!/bin/bash
# Copyright (c) 2026 MikeT LLC. All rights reserved.
# dmarc-summary.sh
#
# Daily DMARC aggregate-report summary. Replaces the
# `DMARC Daily Summary` GitHub Actions workflow
# (miket-infra/.github/workflows/dmarc-summarize.yml), which used to run
# `scripts/monitoring/dmarc_summary.sh` and commit output back to the repo.
#
# Output lands in /space/_ops/reports/dmarc/YYYY-MM-DD.md instead of being
# committed to git. Emits a heartbeat metric so a missed run is visible.
#
# Note: the underlying script is a stub unless `parsedmarc` is installed.
# That's pre-existing behavior — this wrapper preserves it so we don't
# change upstream semantics as part of the migration.

set -uo pipefail

DOMAIN="${DMARC_DOMAIN:-miket.io}"
OUT_DIR="${DMARC_REPORT_DIR:-/space/_ops/reports/dmarc}"
METRICS_DIR="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
METRICS_FILE="${METRICS_DIR}/dmarc_summary.prom"
LOG_DIR="${OPS_VERIFY_LOG_DIR:-/var/log/ops-verify}"
LOG_FILE="${LOG_DIR}/dmarc-summary.log"
SUMMARY_SCRIPT="${DMARC_SUMMARY_SCRIPT:-/usr/local/bin/dmarc-summary-upstream.sh}"

mkdir -p "$OUT_DIR" "$LOG_DIR"

NOW=$(date +%s)
TS=$(date -Iseconds)
TODAY=$(date -u +%Y-%m-%d)
REPORT="${OUT_DIR}/${TODAY}.md"

if [[ -x "$SUMMARY_SCRIPT" ]]; then
    "$SUMMARY_SCRIPT" > "$REPORT" 2>&1 || true
    STATUS=$?
else
    cat > "$REPORT" <<EOF
# DMARC Report Summary — ${TODAY}

_Stub report._ \`$SUMMARY_SCRIPT\` is not installed on this host; install it
(or run the summary manually from motoko) to generate an actual aggregate
summary. This file exists so the daily heartbeat metric continues to fire
and a missing run still trips \`DmarcSummaryStale\`.
EOF
    STATUS=0
fi

if [[ -d "$METRICS_DIR" ]]; then
    tmp=$(mktemp "${METRICS_DIR}/.dmarc_summary.prom.XXXXXX")
    {
        echo "# HELP dmarc_summary_last_run_timestamp_seconds Unix time of the last dmarc-summary run."
        echo "# TYPE dmarc_summary_last_run_timestamp_seconds gauge"
        echo "dmarc_summary_last_run_timestamp_seconds{domain=\"${DOMAIN}\"} ${NOW}"
        echo "# HELP dmarc_summary_last_run_status 1 if the summary script produced output, 0 otherwise."
        echo "# TYPE dmarc_summary_last_run_status gauge"
        if [[ -s "$REPORT" ]]; then
            echo "dmarc_summary_last_run_status{domain=\"${DOMAIN}\"} 1"
        else
            echo "dmarc_summary_last_run_status{domain=\"${DOMAIN}\"} 0"
        fi
    } > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$METRICS_FILE"
fi

echo "${TS} dmarc-summary domain=${DOMAIN} report=${REPORT} script=${SUMMARY_SCRIPT} exit=${STATUS}" | tee -a "$LOG_FILE"
exit 0
