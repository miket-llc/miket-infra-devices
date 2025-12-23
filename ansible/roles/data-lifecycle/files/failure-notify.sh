#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# failure-notify.sh
# Called by failure-notify@.service when a data lifecycle job fails
# Logs failure to /var/log/systemd-failures.log and writes marker file
#
# Notification Channels (per P0 Bulletproof Backups mandate):
# 1. Local logging (/var/log/systemd-failures.log)
# 2. Data Estate logging (/space/_ops/logs/data-lifecycle/failures.log)
# 3. Marker file for collectors (/space/_ops/data-estate/markers/last_failure.json)
# 4. Webhook hook (configurable, for Slack/PagerDuty/etc.)
#
# Usage: failure-notify.sh <unit-name>

set -euo pipefail

FAILED_UNIT="${1:-unknown}"
TIMESTAMP="$(date -Iseconds)"
HOSTNAME="$(hostname)"
LOG_FILE="/var/log/systemd-failures.log"
SPACE_LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"

# Webhook configuration (optional)
# Set FAILURE_WEBHOOK_URL in environment or /etc/miket/failure-notify.env
WEBHOOK_URL="${FAILURE_WEBHOOK_URL:-}"
WEBHOOK_ENV_FILE="/etc/miket/failure-notify.env"

# =============================================================================
# Log to /var/log/systemd-failures.log (primary)
# =============================================================================

echo "[${TIMESTAMP}] FAILURE: ${FAILED_UNIT} failed on ${HOSTNAME}" >> "${LOG_FILE}"
journalctl -u "${FAILED_UNIT}" --no-pager -n 50 >> "${LOG_FILE}" 2>/dev/null || true
echo "---" >> "${LOG_FILE}"

# =============================================================================
# Log to /space/_ops (secondary, for data estate)
# =============================================================================

if [[ -d "${SPACE_LOG_DIR}" ]] || mkdir -p "${SPACE_LOG_DIR}" 2>/dev/null; then
    echo "[${TIMESTAMP}] FAILURE: ${FAILED_UNIT} failed on ${HOSTNAME}" >> "${SPACE_LOG_DIR}/failures.log"
    journalctl -u "${FAILED_UNIT}" --no-pager -n 50 >> "${SPACE_LOG_DIR}/failures.log" 2>/dev/null || true
    echo "---" >> "${SPACE_LOG_DIR}/failures.log"
fi

# =============================================================================
# Write failure marker for Data Estate collector
# =============================================================================

if mkdir -p "${MARKERS_DIR}" 2>/dev/null; then
    MARKER_FILE="${MARKERS_DIR}/last_failure.json"
    TEMP_FILE=$(mktemp "${MARKERS_DIR}/.last_failure.XXXXXX")

    cat > "${TEMP_FILE}" << EOF
{
  "failed_unit": "${FAILED_UNIT}",
  "host": "${HOSTNAME}",
  "timestamp": "${TIMESTAMP}",
  "message": "Service ${FAILED_UNIT} failed"
}
EOF

    mv "${TEMP_FILE}" "${MARKER_FILE}"
    chmod 644 "${MARKER_FILE}"
fi

# =============================================================================
# Webhook Notification (optional, for Slack/PagerDuty/Discord/etc.)
# =============================================================================

# Load webhook URL from env file if not set
if [[ -z "${WEBHOOK_URL}" ]] && [[ -f "${WEBHOOK_ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${WEBHOOK_ENV_FILE}" 2>/dev/null || true
    WEBHOOK_URL="${FAILURE_WEBHOOK_URL:-}"
fi

# Send webhook if configured
if [[ -n "${WEBHOOK_URL}" ]]; then
    # Get last 20 lines of failed unit log for context
    UNIT_LOG=$(journalctl -u "${FAILED_UNIT}" --no-pager -n 20 2>/dev/null | tail -20 || echo "Log unavailable")

    # Build JSON payload (compatible with Slack/Discord incoming webhooks)
    PAYLOAD=$(cat << EOF
{
  "text": "Backup Failure Alert",
  "blocks": [
    {
      "type": "header",
      "text": {"type": "plain_text", "text": "Backup Failure Alert", "emoji": true}
    },
    {
      "type": "section",
      "fields": [
        {"type": "mrkdwn", "text": "*Unit:*\n${FAILED_UNIT}"},
        {"type": "mrkdwn", "text": "*Host:*\n${HOSTNAME}"},
        {"type": "mrkdwn", "text": "*Time:*\n${TIMESTAMP}"}
      ]
    },
    {
      "type": "section",
      "text": {"type": "mrkdwn", "text": "*Recent Log:*\n\`\`\`${UNIT_LOG:0:1500}\`\`\`"}
    }
  ]
}
EOF
)

    # Send webhook (non-blocking, don't fail the notification on webhook errors)
    if curl -s -X POST -H "Content-Type: application/json" -d "${PAYLOAD}" "${WEBHOOK_URL}" --max-time 10 >/dev/null 2>&1; then
        echo "Webhook notification sent to configured endpoint"
    else
        echo "WARNING: Webhook notification failed (endpoint may be unreachable)"
    fi
else
    echo "Webhook not configured (set FAILURE_WEBHOOK_URL in ${WEBHOOK_ENV_FILE} to enable)"
fi

echo "Failure notification logged for ${FAILED_UNIT}"




