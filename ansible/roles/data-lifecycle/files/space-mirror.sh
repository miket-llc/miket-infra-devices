#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# space-mirror.sh
# 1:1 Mirror of /space to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Secrets (retrieved via Ansible/Environment from Azure Key Vault)
# B2_APPLICATION_KEY_ID / B2_APPLICATION_KEY (from /etc/miket/storage-credentials.env)

SOURCE="/space"
# Use backend notation so rclone can operate without a named remote in rclone.conf
DEST=":b2:miket-space-mirror"
LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/space-mirror.log"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/b2_mirror.json"
HOSTNAME=$(hostname)

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
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.b2_mirror.XXXXXX")
    
    cat > "$temp_file" << EOF
{
  "job": "b2_mirror",
  "host": "${HOSTNAME}",
  "timestamp": "$(date -Iseconds)",
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
    log_and_output "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko"
    exit 1
fi

# Rclone Configuration (environment based for safety)
export RCLONE_B2_HARD_DELETE=true
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

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
    
    log_and_output "[$(date)] Space Mirror Complete."
    
    # Write success marker ONLY after successful sync
    write_marker "success" "Mirror sync completed successfully" "${FILES_TRANSFERRED:-0}" "${BYTES_TRANSFERRED:-0}"
    exit 0
else
    EXIT_CODE=${PIPESTATUS[0]}
    rm -f "$SYNC_OUTPUT"
    log_and_output "[$(date)] Space Mirror FAILED with exit code $EXIT_CODE"
    # Do NOT update marker on failure - preserve last success timestamp
    exit $EXIT_CODE
fi
