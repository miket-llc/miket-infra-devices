#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# restic-check.sh
# Scheduled integrity verification of restic repositories
# Per P0 Bulletproof Backups mandate
#
# Runs restic check to verify:
# - Repository integrity (data structures)
# - Data integrity (optional --read-data for full verification)

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

REPO="${RESTIC_REPO:-b2:miket-backups-restic:flux}"
LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/restic-check.log"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/restic_check.json"
HOSTNAME=$(hostname)

# Timing
START_TIME=$(date +%s)
START_TIMESTAMP=$(date -Iseconds)

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# =============================================================================
# Helper Functions
# =============================================================================

log_and_output() {
    echo "$*" | tee -a "$LOG_FILE"
}

# Write marker file (atomic write)
write_marker() {
    local status="$1"
    local message="${2:-}"
    local check_type="${3:-structure}"
    local duration_seconds="${4:-0}"
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.restic_check.XXXXXX")

    mkdir -p "$MARKERS_DIR"
    cat > "$temp_file" << EOF
{
  "job": "restic_check",
  "host": "${HOSTNAME}",
  "started_at": "${START_TIMESTAMP}",
  "completed_at": "$(date -Iseconds)",
  "duration_seconds": ${duration_seconds},
  "repo": "${REPO}",
  "check_type": "${check_type}",
  "status": "${status}",
  "message": "${message}"
}
EOF

    # Atomic move - only updates marker if write succeeds
    mv "$temp_file" "$MARKER_FILE"
    chmod 644 "$MARKER_FILE"
    log_and_output "[$(date)] Marker file updated: ${MARKER_FILE}"
}

# =============================================================================
# Credential Validation
# =============================================================================

if [[ -z "${RESTIC_PASSWORD:-}" ]] || [[ -z "${B2_ACCOUNT_ID:-}" ]] || [[ -z "${B2_ACCOUNT_KEY:-}" ]]; then
    log_and_output "[$(date)] ERROR: Restic credentials missing from environment"
    log_and_output "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit $(hostname)"
    exit 1
fi

# =============================================================================
# Network Preflight Check
# =============================================================================

log_and_output "[$(date)] Running network preflight check..."

if ! host api.backblazeb2.com >/dev/null 2>&1; then
    log_and_output "[$(date)] ERROR: DNS resolution failed for api.backblazeb2.com"
    exit 1
fi

if ! timeout 10 bash -c 'cat < /dev/null > /dev/tcp/api.backblazeb2.com/443' 2>/dev/null; then
    log_and_output "[$(date)] ERROR: Cannot connect to api.backblazeb2.com:443"
    exit 1
fi
log_and_output "[$(date)] ✓ Network connectivity OK"

# =============================================================================
# Repository Check
# =============================================================================

log_and_output "[$(date)] =========================================="
log_and_output "[$(date)] Restic Repository Integrity Check"
log_and_output "[$(date)] =========================================="
log_and_output "[$(date)] Repository: ${REPO}"

# Determine check type: weekly full read, daily structure only
DAY_OF_WEEK=$(date +%u)
if [[ "$DAY_OF_WEEK" -eq 7 ]]; then
    # Sunday: full data verification (reads all data blobs)
    CHECK_TYPE="full"
    log_and_output "[$(date)] Running FULL data verification (Sunday)"
    CHECK_CMD="restic -r ${REPO} check --read-data"
else
    # Other days: structure only (faster)
    CHECK_TYPE="structure"
    log_and_output "[$(date)] Running structure verification"
    CHECK_CMD="restic -r ${REPO} check"
fi

if $CHECK_CMD 2>&1 | tee -a "$LOG_FILE"; then
    END_TIME=$(date +%s)
    DURATION_SECONDS=$((END_TIME - START_TIME))
    DURATION_HUMAN=$(printf '%dh %dm %ds' $((DURATION_SECONDS/3600)) $((DURATION_SECONDS%3600/60)) $((DURATION_SECONDS%60)))

    log_and_output "[$(date)] =========================================="
    log_and_output "[$(date)] Integrity Check PASSED"
    log_and_output "[$(date)] Duration: ${DURATION_HUMAN} (${DURATION_SECONDS}s)"
    log_and_output "[$(date)] =========================================="

    write_marker "success" "Integrity check passed" "$CHECK_TYPE" "$DURATION_SECONDS"
    exit 0
else
    EXIT_CODE=$?
    END_TIME=$(date +%s)
    DURATION_SECONDS=$((END_TIME - START_TIME))

    log_and_output "[$(date)] =========================================="
    log_and_output "[$(date)] Integrity Check FAILED (exit code: $EXIT_CODE)"
    log_and_output "[$(date)] Duration: ${DURATION_SECONDS}s"
    log_and_output "[$(date)] =========================================="
    log_and_output "[$(date)] CRITICAL: Repository may be corrupted!"
    log_and_output "[$(date)] Review logs and consider running: restic -r ${REPO} rebuild-index"

    # Do NOT update marker on failure - preserve last success timestamp
    exit $EXIT_CODE
fi
