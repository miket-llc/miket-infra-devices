#!/bin/bash
# Copyright (c) 2026 MikeT LLC. All rights reserved.
# recovery-attestation.sh
#
# Weekly break-glass / SSPR attestation. Replaces miket-infra's
# `.github/workflows/recovery-attestation.yml`, which was deferred during
# the GHA → akira migration because the verify scripts need Graph API
# permissions (User.Read.All, UserAuthenticationMethod.Read.All,
# Policy.Read.All) that mdt's user-context az login doesn't have.
#
# We now have a dedicated Entra app (`ops_verify`) with the right scopes
# and a cert in AKV (`ops-verify-sp-cert-pfx`). This script:
#   1. Fetches the PFX as the local user that owns the az creds (mdt),
#      decodes + stashes it on tmpfs at /run/ops-verify/.
#   2. Runs `az login --service-principal` into a side AZURE_CONFIG_DIR
#      so the SP's session never collides with mdt's interactive one.
#   3. Runs the existing verify scripts from the miket-infra checkout.
#   4. Writes the weekly attestation report to /space/_ops/reports/recovery/.
#   5. Emits Prometheus textfile metrics.
#   6. Shreds the cert material before exit.

set -uo pipefail

INFRA_DIR="${INFRA_DIR:-/flux/ops/miket-infra}"
METRICS_DIR="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
METRICS_FILE="${METRICS_DIR}/recovery_attestation.prom"
LOG_DIR="${OPS_VERIFY_LOG_DIR:-/var/log/ops-verify}"
LOG_FILE="${LOG_DIR}/recovery-attestation.log"
REPORT_DIR="${RECOVERY_REPORT_DIR:-/space/_ops/reports/recovery}"

AZ_USER="${AZ_USER:-mdt}"
VAULT="${AKV_VAULT:-kv-miket-ops}"
PFX_SECRET="${AKV_PFX_SECRET:-ops-verify-sp-cert-pfx}"
APP_ID_SECRET="${AKV_APP_ID_SECRET:-ops-verify-sp-app-id}"
TENANT_ID="${TENANT_ID:-cd6aed39-39c7-44ec-9eeb-6eb23f6dcad0}"

RUN_DIR=$(mktemp -d -p /run ops-verify.XXXXXX)
chmod 0700 "$RUN_DIR"
AZURE_CONFIG_DIR="$RUN_DIR/azure"
PFX_PATH="$RUN_DIR/sp.pfx"
PEM_PATH="$RUN_DIR/sp.pem"

cleanup() {
    [[ -f "$PFX_PATH" ]] && shred -u "$PFX_PATH" 2>/dev/null
    [[ -f "$PEM_PATH" ]] && shred -u "$PEM_PATH" 2>/dev/null
    rm -rf "$RUN_DIR" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$LOG_DIR" "$REPORT_DIR"

NOW=$(date +%s)
TS=$(date -Iseconds)
TODAY=$(date -u +%Y-%m-%d)
REPORT="${REPORT_DIR}/${TODAY}-attestation.md"

# _az_mdt runs an az command under the local user's credential cache (mdt).
# Used only for the bootstrap step: fetching the SP cert from AKV.
_az_mdt() {
    if [[ $(id -u) -eq 0 ]]; then
        runuser -u "$AZ_USER" -- az "$@"
    else
        az "$@"
    fi
}

# Fetch PFX + appId from AKV
echo "${TS} recovery-attestation: fetching SP material from $VAULT" | tee -a "$LOG_FILE"
APP_ID=$(_az_mdt keyvault secret show --vault-name "$VAULT" --name "$APP_ID_SECRET" --query value -o tsv 2>>"$LOG_FILE")
_az_mdt keyvault secret show --vault-name "$VAULT" --name "$PFX_SECRET" --query value -o tsv 2>>"$LOG_FILE" | base64 -d > "$PFX_PATH"

if [[ ! -s "$PFX_PATH" ]] || [[ -z "$APP_ID" ]]; then
    echo "${TS} recovery-attestation: failed to retrieve SP material" | tee -a "$LOG_FILE"
    exit_code=1
    overall=0
    goto_emit=1
fi

if [[ -z "${goto_emit:-}" ]]; then
    # Convert PFX → PEM for az login --certificate
    openssl pkcs12 -in "$PFX_PATH" -out "$PEM_PATH" -nodes -passin pass: 2>>"$LOG_FILE"

    # Sign in as the ops_verify SP into a side config dir
    export AZURE_CONFIG_DIR
    mkdir -p "$AZURE_CONFIG_DIR"
    az login --service-principal --username "$APP_ID" --certificate "$PEM_PATH" \
        --tenant "$TENANT_ID" --allow-no-subscriptions \
        > /dev/null 2>>"$LOG_FILE"
    login_exit=$?

    if [[ $login_exit -ne 0 ]]; then
        echo "${TS} recovery-attestation: az SP login failed (exit=$login_exit)" | tee -a "$LOG_FILE"
        exit_code=1
        overall=0
    else
        echo "${TS} recovery-attestation: authenticated as $APP_ID" | tee -a "$LOG_FILE"
        # Run upstream verify scripts from the miket-infra checkout.
        cd "$INFRA_DIR"
        BREAKGLASS_OUT="$RUN_DIR/breakglass.out"
        SSPR_OUT="$RUN_DIR/sspr.out"
        REPORT_OUT="$RUN_DIR/report.out"

        bash scripts/verify/breakglass_fido2_check.sh > "$BREAKGLASS_OUT" 2>&1
        breakglass_exit=$?

        bash scripts/verify/sspr_enablement_check.sh > "$SSPR_OUT" 2>&1
        sspr_exit=$?

        if [[ -x scripts/verify/generate_recovery_report.sh ]]; then
            bash scripts/verify/generate_recovery_report.sh > "$REPORT_OUT" 2>&1 || true
            # Upstream writes to reports/recovery/YYYY-MM-DD-attestation.md
            # (repo-relative). Copy into /space if present.
            UPSTREAM_REPORT="${INFRA_DIR}/reports/recovery/${TODAY}-attestation.md"
            if [[ -f "$UPSTREAM_REPORT" ]]; then
                cp "$UPSTREAM_REPORT" "$REPORT"
            fi
        fi

        # Compose our own report if upstream didn't write one
        if [[ ! -f "$REPORT" ]]; then
            {
                echo "# Recovery Attestation Report — ${TODAY}"
                echo
                echo "**Break-glass FIDO2 check exit:** ${breakglass_exit}"
                echo "**SSPR enablement check exit:**   ${sspr_exit}"
                echo
                echo "## Break-glass output"
                echo '```'
                cat "$BREAKGLASS_OUT"
                echo '```'
                echo
                echo "## SSPR output"
                echo '```'
                cat "$SSPR_OUT"
                echo '```'
            } > "$REPORT"
        fi

        # Log out of the SP session
        az logout > /dev/null 2>&1 || true

        if [[ $breakglass_exit -eq 0 && $sspr_exit -eq 0 ]]; then
            overall=1
            exit_code=0
        else
            overall=0
            exit_code=1
        fi
    fi
fi

# Emit textfile metrics
if [[ -d "$METRICS_DIR" ]]; then
    tmp=$(mktemp "${METRICS_DIR}/.recovery_attestation.prom.XXXXXX")
    {
        echo "# HELP recovery_attestation_last_run_timestamp_seconds Unix time of the last run."
        echo "# TYPE recovery_attestation_last_run_timestamp_seconds gauge"
        echo "recovery_attestation_last_run_timestamp_seconds ${NOW}"
        echo "# HELP recovery_attestation_last_run_status 1 if break-glass + SSPR checks both passed, 0 otherwise."
        echo "# TYPE recovery_attestation_last_run_status gauge"
        echo "recovery_attestation_last_run_status ${overall:-0}"
        echo "# HELP recovery_attestation_breakglass_status 1 if break-glass FIDO2 registration check passed."
        echo "# TYPE recovery_attestation_breakglass_status gauge"
        if [[ -n "${breakglass_exit:-}" ]]; then
            echo "recovery_attestation_breakglass_status $(( breakglass_exit == 0 ? 1 : 0 ))"
        else
            echo "recovery_attestation_breakglass_status 0"
        fi
        echo "# HELP recovery_attestation_sspr_status 1 if SSPR policy check passed."
        echo "# TYPE recovery_attestation_sspr_status gauge"
        if [[ -n "${sspr_exit:-}" ]]; then
            echo "recovery_attestation_sspr_status $(( sspr_exit == 0 ? 1 : 0 ))"
        else
            echo "recovery_attestation_sspr_status 0"
        fi
    } > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$METRICS_FILE"
fi

echo "${TS} recovery-attestation: overall=${overall:-0} breakglass=${breakglass_exit:-?} sspr=${sspr_exit:-?} report=${REPORT}" | tee -a "$LOG_FILE"
exit "${exit_code:-0}"
