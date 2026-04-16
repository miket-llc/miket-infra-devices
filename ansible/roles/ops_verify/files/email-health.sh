#!/bin/bash
# Copyright (c) 2026 MikeT LLC. All rights reserved.
# email-health.sh
#
# Hourly email-infrastructure health probe. Covers MX, SPF, DMARC, MTA-STS, and
# TLS-RPT DNS records for the configured domain. DKIM lives in dkim-verify.sh
# (runs every 30m at its own cadence).
#
# Replaces the `Email Infrastructure Health Check` GitHub Actions workflow
# (miket-infra/.github/workflows/email-health.yml).

set -uo pipefail

DOMAIN="${EMAIL_DOMAIN:-miket.io}"
METRICS_DIR="${NODE_EXPORTER_TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
METRICS_FILE="${METRICS_DIR}/email_health.prom"
LOG_DIR="${OPS_VERIFY_LOG_DIR:-/var/log/ops-verify}"
LOG_FILE="${LOG_DIR}/email-health.log"

mkdir -p "$LOG_DIR"

NOW=$(date +%s)
TS=$(date -Iseconds)

dig_short() {
    dig +short +tries=2 +time=3 "$@" 2>/dev/null || true
}

# --- MX ---
MX_ANSWER=$(dig_short "$DOMAIN" MX | head -1)
[[ -n "$MX_ANSWER" ]] && MX_OK=1 || MX_OK=0

# --- SPF ---
SPF_ANSWER=$(dig_short "$DOMAIN" TXT | grep -i "v=spf1" || true)
[[ -n "$SPF_ANSWER" ]] && SPF_OK=1 || SPF_OK=0

# --- DMARC ---
DMARC_ANSWER=$(dig_short "_dmarc.${DOMAIN}" TXT | grep -i "v=DMARC1" || true)
if [[ -n "$DMARC_ANSWER" ]]; then
    DMARC_OK=1
    DMARC_POLICY=$(echo "$DMARC_ANSWER" | grep -oE "p=[a-z]+" | head -1 | cut -d= -f2 || echo "none")
else
    DMARC_OK=0
    DMARC_POLICY="none"
fi

# --- MTA-STS ---
MTA_STS_ANSWER=$(dig_short "_mta-sts.${DOMAIN}" TXT | grep -i "v=STSv1" || true)
[[ -n "$MTA_STS_ANSWER" ]] && MTA_STS_OK=1 || MTA_STS_OK=0

# --- TLS-RPT ---
TLSRPT_ANSWER=$(dig_short "_smtp._tls.${DOMAIN}" TXT | grep -i "v=TLSRPTv1" || true)
[[ -n "$TLSRPT_ANSWER" ]] && TLSRPT_OK=1 || TLSRPT_OK=0

# Aggregate status: 1 if all pass, 0 otherwise. Exit code matches.
FAILED=$(( (MX_OK != 1) + (SPF_OK != 1) + (DMARC_OK != 1) + (MTA_STS_OK != 1) + (TLSRPT_OK != 1) ))
if [[ $FAILED -eq 0 ]]; then
    OVERALL=1
    EXIT_CODE=0
else
    OVERALL=0
    EXIT_CODE=1
fi

if [[ -d "$METRICS_DIR" ]]; then
    tmp=$(mktemp "${METRICS_DIR}/.email_health.prom.XXXXXX")
    {
        echo "# HELP email_check_success 1 if the named email-infra DNS record exists and is well-formed; 0 otherwise."
        echo "# TYPE email_check_success gauge"
        echo "email_check_success{domain=\"${DOMAIN}\",check=\"mx\"} ${MX_OK}"
        echo "email_check_success{domain=\"${DOMAIN}\",check=\"spf\"} ${SPF_OK}"
        echo "email_check_success{domain=\"${DOMAIN}\",check=\"dmarc\"} ${DMARC_OK}"
        echo "email_check_success{domain=\"${DOMAIN}\",check=\"mta_sts\"} ${MTA_STS_OK}"
        echo "email_check_success{domain=\"${DOMAIN}\",check=\"tls_rpt\"} ${TLSRPT_OK}"
        echo "# HELP email_health_failed_checks Number of failing checks out of 5 (MX/SPF/DMARC/MTA-STS/TLS-RPT)."
        echo "# TYPE email_health_failed_checks gauge"
        echo "email_health_failed_checks{domain=\"${DOMAIN}\"} ${FAILED}"
        echo "# HELP email_health_last_run_timestamp_seconds Unix time of the last email-health run."
        echo "# TYPE email_health_last_run_timestamp_seconds gauge"
        echo "email_health_last_run_timestamp_seconds{domain=\"${DOMAIN}\"} ${NOW}"
        echo "# HELP email_health_overall_status 1 if all checks pass, 0 otherwise."
        echo "# TYPE email_health_overall_status gauge"
        echo "email_health_overall_status{domain=\"${DOMAIN}\"} ${OVERALL}"
        echo "# HELP email_dmarc_policy_info Static gauge carrying the DMARC policy string in a label."
        echo "# TYPE email_dmarc_policy_info gauge"
        echo "email_dmarc_policy_info{domain=\"${DOMAIN}\",policy=\"${DMARC_POLICY}\"} 1"
    } > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$METRICS_FILE"
fi

echo "${TS} email-health domain=${DOMAIN} mx=${MX_OK} spf=${SPF_OK} dmarc=${DMARC_OK}(p=${DMARC_POLICY}) mta_sts=${MTA_STS_OK} tls_rpt=${TLSRPT_OK} failed=${FAILED} exit=${EXIT_CODE}" | tee -a "$LOG_FILE"

exit "$EXIT_CODE"
