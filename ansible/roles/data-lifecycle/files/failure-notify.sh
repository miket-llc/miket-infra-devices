#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# failure-notify.sh
# Called by failure-notify@.service when a data lifecycle job fails
# Logs failure to /var/log/systemd-failures.log and writes marker file
#
# Usage: failure-notify.sh <unit-name>

set -euo pipefail

FAILED_UNIT="${1:-unknown}"
TIMESTAMP="$(date -Iseconds)"
HOSTNAME="$(hostname)"
LOG_FILE="/var/log/systemd-failures.log"
SPACE_LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"

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

echo "Failure notification logged for ${FAILED_UNIT}"




