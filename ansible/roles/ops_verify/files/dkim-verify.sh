#!/bin/bash
# Copyright (c) 2026 MikeT LLC. All rights reserved.
# dkim-verify.sh
#
# Checks that selector1 and selector2 for the configured DKIM domain each
# resolve to a TXT record containing `v=DKIM1`. Emits node_exporter textfile
# metrics so the observability_stack alertmanager can catch regressions.
#
# Replaces the `DKIM Verification` GitHub Actions workflow
# (miket-infra/.github/workflows/dkim-verify.yml).

set -uo pipefail

DOMAIN="${DKIM_DOMAIN:-miket.io}"
METRICS_DIR="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
METRICS_FILE="${METRICS_DIR}/dkim_verify.prom"
LOG_DIR="${OPS_VERIFY_LOG_DIR:-/var/log/ops-verify}"
LOG_FILE="${LOG_DIR}/dkim-verify.log"

mkdir -p "$LOG_DIR"

NOW=$(date +%s)
TS=$(date -Iseconds)

check_selector() {
    # Echo "1" if selector's TXT record contains v=DKIM1; "0" otherwise.
    local sel="$1"
    local answer
    answer=$(dig +short +tries=2 +time=3 TXT "${sel}._domainkey.${DOMAIN}" 2>/dev/null || true)
    if [[ "$answer" == *"v=DKIM1"* ]]; then
        echo 1
    else
        echo 0
    fi
}

S1=$(check_selector "selector1")
S2=$(check_selector "selector2")

if [[ "$S1" == "1" && "$S2" == "1" ]]; then
    OVERALL=1
    EXIT_CODE=0
    STATUS_MSG="both selectors valid"
else
    OVERALL=0
    EXIT_CODE=1
    STATUS_MSG="selector1=${S1} selector2=${S2}"
fi

# Atomic textfile collector write (tmp + rename so the scraper never sees
# partial content).
if [[ -d "$METRICS_DIR" ]]; then
    tmp=$(mktemp "${METRICS_DIR}/.dkim_verify.prom.XXXXXX")
    {
        echo "# HELP dkim_selector_valid 1 if the selector's TXT record contains v=DKIM1; 0 otherwise."
        echo "# TYPE dkim_selector_valid gauge"
        echo "dkim_selector_valid{domain=\"${DOMAIN}\",selector=\"selector1\"} ${S1}"
        echo "dkim_selector_valid{domain=\"${DOMAIN}\",selector=\"selector2\"} ${S2}"
        echo "# HELP dkim_verify_last_run_timestamp_seconds Unix time of the last DKIM verification run."
        echo "# TYPE dkim_verify_last_run_timestamp_seconds gauge"
        echo "dkim_verify_last_run_timestamp_seconds{domain=\"${DOMAIN}\"} ${NOW}"
        echo "# HELP dkim_verify_last_run_status 1 if both selectors valid, 0 otherwise."
        echo "# TYPE dkim_verify_last_run_status gauge"
        echo "dkim_verify_last_run_status{domain=\"${DOMAIN}\"} ${OVERALL}"
    } > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$METRICS_FILE"
fi

echo "${TS} dkim-verify domain=${DOMAIN} ${STATUS_MSG} exit=${EXIT_CODE}" | tee -a "$LOG_FILE"

exit "$EXIT_CODE"
