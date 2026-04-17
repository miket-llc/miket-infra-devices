#!/bin/bash
# Copyright (c) 2026 MikeT LLC. All rights reserved.
# secrets-drift.sh
#
# Hourly secrets-inventory drift probe. Runs
# `scripts/security/secrets_drift.py` against `.ops/secrets.yaml` from a
# local miket-infra checkout, parses the markdown report for per-severity
# counts, and emits Prometheus textfile metrics.
#
# Replaces the `Secrets Drift Detection` GitHub Actions workflow
# (miket-infra/.github/workflows/secrets-drift.yml). Also subsumes
# `secrets-expiry-reminders.yml`: both read `.ops/secrets.yaml` and the
# expiry thresholds in secrets_drift.py are the same (30d warning, 7d
# alert), so one check covers both with Alertmanager-driven Discord pings
# instead of GitHub issues.

set -uo pipefail

INFRA_DIR="${INFRA_DIR:-/flux/ops/miket-infra}"
VENV="${OPS_VERIFY_VENV:-/flux/ops/ops-verify-venv}"
METRICS_DIR="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
METRICS_FILE="${METRICS_DIR}/secrets_drift.prom"
LOG_DIR="${OPS_VERIFY_LOG_DIR:-/var/log/ops-verify}"
LOG_FILE="${LOG_DIR}/secrets-drift.log"
REPORT_DIR="${SECRETS_DRIFT_REPORT_DIR:-/space/_ops/reports/secrets}"
REPORT_FILE="${REPORT_DIR}/latest.md"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

NOW=$(date +%s)
TS=$(date -Iseconds)

# Refresh the inventory from origin. Root-side HTTPS auth uses the
# credential helper configured by the ops_verify role (see
# /etc/gitconfig-miket). If the fetch fails for any reason, we continue
# with the already-checked-out inventory so we still emit metrics; a
# failure is logged but not fatal.
if [[ -d "${INFRA_DIR}/.git" ]]; then
    timeout 30 git -C "$INFRA_DIR" fetch --quiet origin main 2>>"$LOG_FILE" && \
        git -C "$INFRA_DIR" reset --hard origin/main --quiet 2>>"$LOG_FILE" || \
        echo "$(date -Iseconds) secrets-drift fetch failed, using existing inventory" >>"$LOG_FILE"
fi

# Run the inventory check.
"$VENV/bin/python" "${INFRA_DIR}/scripts/security/secrets_drift.py" \
    --inventory "${INFRA_DIR}/.ops/secrets.yaml" \
    --markdown "$REPORT_FILE" \
    > /dev/null 2>>"$LOG_FILE"
SCRIPT_EXIT=$?

ALERT=0
WARNING=0
OK=0
if [[ -s "$REPORT_FILE" ]]; then
    # The report table uses "| ALERT |", "| WARNING |", "| OK |" in the status column.
    ALERT=$(grep -c '| ALERT |' "$REPORT_FILE" || true)
    WARNING=$(grep -c '| WARNING |' "$REPORT_FILE" || true)
    OK=$(grep -c '| OK |' "$REPORT_FILE" || true)
fi
TOTAL=$((ALERT + WARNING + OK))

if [[ -d "$METRICS_DIR" ]]; then
    tmp=$(mktemp "${METRICS_DIR}/.secrets_drift.prom.XXXXXX")
    {
        echo "# HELP secrets_drift_secrets_total Count of secrets in the inventory by evaluated status."
        echo "# TYPE secrets_drift_secrets_total gauge"
        echo "secrets_drift_secrets_total{status=\"alert\"} ${ALERT}"
        echo "secrets_drift_secrets_total{status=\"warning\"} ${WARNING}"
        echo "secrets_drift_secrets_total{status=\"ok\"} ${OK}"
        echo "# HELP secrets_drift_inventory_size Total secrets tracked in .ops/secrets.yaml."
        echo "# TYPE secrets_drift_inventory_size gauge"
        echo "secrets_drift_inventory_size ${TOTAL}"
        echo "# HELP secrets_drift_last_run_timestamp_seconds Unix time of the last secrets-drift run."
        echo "# TYPE secrets_drift_last_run_timestamp_seconds gauge"
        echo "secrets_drift_last_run_timestamp_seconds ${NOW}"
        echo "# HELP secrets_drift_last_run_status 1 if the script ran to completion, 0 if it errored."
        echo "# TYPE secrets_drift_last_run_status gauge"
        if [[ -s "$REPORT_FILE" ]]; then
            echo "secrets_drift_last_run_status 1"
        else
            echo "secrets_drift_last_run_status 0"
        fi
    } > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$METRICS_FILE"
fi

echo "${TS} secrets-drift alert=${ALERT} warning=${WARNING} ok=${OK} total=${TOTAL} script_exit=${SCRIPT_EXIT}" | tee -a "$LOG_FILE"

# AKV cross-check: for every keyvault-store inventory entry, compare
# `last_rotated` against the AKV `attributes.updated` timestamp. This is
# the drift-detection layer — if the inventory goes stale (secret rotated
# in AKV, YAML not updated), the same phantom-alert failure mode we hit
# once already is now visible as its own metric + alert, not hidden.
if [[ -x /usr/local/bin/akv-inventory-drift.py ]] && [[ -x "$VENV/bin/python" ]]; then
    INVENTORY="${INFRA_DIR}/.ops/secrets.yaml" \
    NODE_EXPORTER_TEXTFILE_DIR="$METRICS_DIR" \
    "$VENV/bin/python" /usr/local/bin/akv-inventory-drift.py >>"$LOG_FILE" 2>&1 || \
        echo "${TS} akv-inventory-drift failed (see log above)" >>"$LOG_FILE"
fi

# Intentionally exit 0 — the metrics + alertmanager are the signal. Exiting
# non-zero on ALERT would just leave the unit in failed state and suppress
# the next tick, hiding recovery.
exit 0
