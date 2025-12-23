#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# space-mirror.sh
# 1:1 Mirror of /space to B2
# Per DATA_LIFECYCLE_SPEC.md
#
# Hardening (per P0 Bulletproof Backups mandate):
# - Exit-code correctness: propagate rclone exit codes
# - Preflight checks: mount, credentials, network, B2 connectivity
# - Duration tracking: capture start/end for metrics
# - Atomic marker writes: only update on success

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Secrets (retrieved via Ansible/Environment from Azure Key Vault)
# B2_APPLICATION_KEY_ID / B2_APPLICATION_KEY (from /etc/miket/storage-credentials.env)

SOURCE="/space"
# Use backend notation so rclone can operate without a named remote in rclone.conf
DEST=":b2:miket-space-mirror"
BUCKET_NAME="miket-space-mirror"
LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/space-mirror.log"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/b2_mirror.json"
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

# Write marker file on success (atomic write)
write_marker() {
    local status="$1"
    local message="${2:-}"
    local files_transferred="${3:-0}"
    local bytes_transferred="${4:-0}"
    local duration_seconds="${5:-0}"
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.b2_mirror.XXXXXX")

    cat > "$temp_file" << EOF
{
  "job": "b2_mirror",
  "host": "${HOSTNAME}",
  "started_at": "${START_TIMESTAMP}",
  "completed_at": "$(date -Iseconds)",
  "duration_seconds": ${duration_seconds},
  "source": "${SOURCE}",
  "destination": "${DEST}",
  "status": "${status}",
  "message": "${message}",
  "files_transferred": ${files_transferred},
  "bytes_transferred": ${bytes_transferred}
}
EOF

    # Atomic move - only updates marker if write succeeds
    mv "$temp_file" "$MARKER_FILE"
    chmod 644 "$MARKER_FILE"
    log_and_output "[$(date)] Marker file updated: ${MARKER_FILE}"
}

# =============================================================================
# Preflight Checks
# =============================================================================

# Verify /space is mounted and accessible
if [[ ! -d "$SOURCE" ]]; then
    log_and_output "[$(date)] ERROR: Source directory not found: $SOURCE"
    log_and_output "[$(date)] ERROR: Is /space mounted?"
    exit 1
fi

# Check for minimum expected content (sanity check - avoid syncing empty mount)
if [[ ! -d "$SOURCE/mike" ]] && [[ ! -d "$SOURCE/projects" ]]; then
    log_and_output "[$(date)] ERROR: /space appears empty or improperly mounted"
    log_and_output "[$(date)] ERROR: Expected subdirectories not found"
    exit 1
fi

# =============================================================================
# Credential Validation
# =============================================================================

if [[ -z "${B2_APPLICATION_KEY_ID:-}" ]] || [[ -z "${B2_APPLICATION_KEY:-}" ]]; then
    log_and_output "[$(date)] ERROR: B2 credentials missing from environment"
    log_and_output "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit $(hostname)"
    exit 1
fi

# Rclone Configuration (environment based for safety)
export RCLONE_B2_HARD_DELETE=true
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

# =============================================================================
# Network Preflight Checks
# =============================================================================

log_and_output "[$(date)] Running network preflight checks..."

# Check DNS resolution (Backblaze B2 API endpoint)
if ! host api.backblazeb2.com >/dev/null 2>&1; then
    log_and_output "[$(date)] ERROR: DNS resolution failed for api.backblazeb2.com"
    log_and_output "[$(date)] ERROR: Check network connectivity and DNS configuration"
    exit 1
fi
log_and_output "[$(date)] ✓ DNS resolution OK"

# Check outbound connectivity to B2 (HTTPS on port 443)
if ! timeout 10 bash -c 'cat < /dev/null > /dev/tcp/api.backblazeb2.com/443' 2>/dev/null; then
    log_and_output "[$(date)] ERROR: Cannot connect to api.backblazeb2.com:443"
    log_and_output "[$(date)] ERROR: Check firewall rules and outbound connectivity"
    exit 1
fi
log_and_output "[$(date)] ✓ Network connectivity OK"

# Verify B2 bucket is accessible with credentials (quick check - 30s timeout)
# Use rclone lsf with --max-depth 1 for a fast top-level listing
if ! timeout 30 rclone lsf "$DEST" --max-depth 1 2>/dev/null | head -1 >/dev/null; then
    log_and_output "[$(date)] ERROR: Cannot access B2 bucket: ${BUCKET_NAME}"
    log_and_output "[$(date)] ERROR: Verify B2 credentials and bucket permissions"
    exit 1
fi
log_and_output "[$(date)] ✓ B2 bucket accessible"

# =============================================================================
# Main Sync Logic
# =============================================================================

log_and_output "[$(date)] Starting Space Mirror..."
log_and_output "[$(date)] Source: $SOURCE"
log_and_output "[$(date)] Destination: $DEST"

# Exclude operational directories that don't need backup and can cause race conditions
# - _ops/logs: Log files are ephemeral and the script writes to its own log during sync
# - _ops/tmp: Temporary files
# - .backup-exclude: Exclude patterns file (if it exists)
EXCLUDE_PATTERNS=(
    --exclude="_ops/logs/**"
    --exclude="_ops/tmp/**"
    --exclude=".backup-exclude"
    --exclude="*.tmp"
    --exclude="*.temp"
    --exclude="*.swp"
    --exclude="*.lock"
)

# Run rclone with JSON stats for marker data
# Add retries for transient file modification errors (common with log files)
SYNC_OUTPUT=$(mktemp)
if rclone sync "$SOURCE" "$DEST" \
    --fast-list \
    --transfers 16 \
    --checkers 16 \
    --track-renames \
    --retries 3 \
    --retries-sleep 5s \
    --stats-one-line \
    --stats-log-level NOTICE \
    --use-json-log \
    --log-file="$LOG_FILE" \
    --log-level=INFO \
    "${EXCLUDE_PATTERNS[@]}" \
    2>&1 | tee "$SYNC_OUTPUT"; then
    
    # Extract stats from JSON log if available
    FILES_TRANSFERRED=$(grep -o '"transfers":[0-9]*' "$SYNC_OUTPUT" | tail -1 | cut -d: -f2 || echo "0")
    BYTES_TRANSFERRED=$(grep -o '"bytes":[0-9]*' "$SYNC_OUTPUT" | tail -1 | cut -d: -f2 || echo "0")
    rm -f "$SYNC_OUTPUT"

    # Calculate duration
    END_TIME=$(date +%s)
    DURATION_SECONDS=$((END_TIME - START_TIME))
    DURATION_HUMAN=$(printf '%dh %dm %ds' $((DURATION_SECONDS/3600)) $((DURATION_SECONDS%3600/60)) $((DURATION_SECONDS%60)))

    log_and_output "[$(date)] Space Mirror Complete."
    log_and_output "[$(date)] Duration: ${DURATION_HUMAN} (${DURATION_SECONDS}s)"
    log_and_output "[$(date)] Files transferred: ${FILES_TRANSFERRED:-0}"
    log_and_output "[$(date)] Bytes transferred: ${BYTES_TRANSFERRED:-0}"

    # Write success marker ONLY after successful sync
    write_marker "success" "Mirror sync completed successfully" "${FILES_TRANSFERRED:-0}" "${BYTES_TRANSFERRED:-0}" "${DURATION_SECONDS}"
    exit 0
else
    EXIT_CODE=${PIPESTATUS[0]}
    rm -f "$SYNC_OUTPUT"

    # Calculate duration even on failure for diagnostics
    END_TIME=$(date +%s)
    DURATION_SECONDS=$((END_TIME - START_TIME))

    log_and_output "[$(date)] Space Mirror FAILED with exit code $EXIT_CODE after ${DURATION_SECONDS}s"
    # Do NOT update marker on failure - preserve last success timestamp
    exit $EXIT_CODE
fi
