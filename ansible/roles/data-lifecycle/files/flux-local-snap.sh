#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# flux-local-snap.sh
# Hourly local snapshots of /flux
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SOURCE="/flux"
REPO="/space/snapshots/flux-local"
PASS_FILE="/root/.restic-local-pass"
LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/flux-local-snap.log"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/restic_local.json"
HOSTNAME=$(hostname)

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# =============================================================================
# Helper Functions
# =============================================================================

log_msg() {
    echo "[$(date)] $*" | tee -a "$LOG_FILE"
}

# Write marker file on success (atomic write)
write_marker() {
    local status="$1"
    local message="${2:-}"
    local snapshot_id="${3:-}"
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.restic_local.XXXXXX")
    
    cat > "$temp_file" << EOF
{
  "job": "restic_local",
  "host": "${HOSTNAME}",
  "timestamp": "$(date -Iseconds)",
  "source": "${SOURCE}",
  "repo": "${REPO}",
  "status": "${status}",
  "message": "${message}",
  "snapshot_id": "${snapshot_id}"
}
EOF
    
    # Atomic move - only updates marker if write succeeds
    mv "$temp_file" "$MARKER_FILE"
    chmod 644 "$MARKER_FILE"
    log_msg "Marker file updated: ${MARKER_FILE}"
}

# =============================================================================
# Preflight Checks
# =============================================================================

# Verify /flux is mounted and accessible
if [[ ! -d "$SOURCE" ]]; then
    log_msg "ERROR: Source directory not found: $SOURCE"
    log_msg "ERROR: Is /flux mounted?"
    exit 1
fi

# Verify /space is mounted (repo location)
if [[ ! -d "$(dirname "$REPO")" ]]; then
    log_msg "ERROR: Repository parent directory not found: $(dirname "$REPO")"
    log_msg "ERROR: Is /space mounted?"
    exit 1
fi

# Verify markers directory is writable
if [[ ! -d "$MARKERS_DIR" ]]; then
    mkdir -p "$MARKERS_DIR" 2>/dev/null || {
        log_msg "ERROR: Cannot create markers directory: $MARKERS_DIR"
        exit 1
    }
fi

# Verify password file exists
if [[ ! -f "$PASS_FILE" ]]; then
    log_msg "ERROR: Local restic password file missing at $PASS_FILE"
    log_msg "Run: ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-lifecycle.yml"
    exit 1
fi

# =============================================================================
# Main Backup Logic
# =============================================================================

log_msg "Starting Flux Local Snapshot..."
log_msg "Source: ${SOURCE}"
log_msg "Repository: ${REPO}"

# Initialize local repo if needed
if [[ ! -d "$REPO/data" ]]; then
    log_msg "Initializing new local restic repository..."
    if ! restic -r "$REPO" init --password-file "$PASS_FILE" >> "$LOG_FILE" 2>&1; then
        EXIT_CODE=$?
        log_msg "ERROR: Failed to initialize restic repository (exit code: $EXIT_CODE)"
        exit $EXIT_CODE
    fi
fi

# Backup with JSON output for snapshot ID extraction
BACKUP_OUTPUT=$(mktemp)
if restic -r "$REPO" backup "$SOURCE" \
    --password-file "$PASS_FILE" \
    --json \
    --exclude-file=/flux/.backup-exclude \
    2>&1 | tee -a "$LOG_FILE" | tee "$BACKUP_OUTPUT"; then
    
    # Extract snapshot ID from JSON output
    SNAPSHOT_ID=$(grep '"message_type":"summary"' "$BACKUP_OUTPUT" | jq -r '.snapshot_id // empty' 2>/dev/null || echo "")
    rm -f "$BACKUP_OUTPUT"
    
    log_msg "Backup completed successfully"
    
    # Write success marker ONLY after successful backup
    write_marker "success" "Local snapshot completed successfully" "$SNAPSHOT_ID"
else
    EXIT_CODE=${PIPESTATUS[0]}
    rm -f "$BACKUP_OUTPUT"
    log_msg "ERROR: Backup failed with exit code $EXIT_CODE"
    # Do NOT update marker on failure - preserve last success timestamp
    exit $EXIT_CODE
fi

# Prune (Short-term retention)
if restic -r "$REPO" forget \
    --password-file "$PASS_FILE" \
    --keep-hourly 24 \
    --keep-daily 7 \
    --prune \
    >> "$LOG_FILE" 2>&1; then
    log_msg "Prune completed successfully"
else
    EXIT_CODE=$?
    log_msg "WARNING: Prune failed with exit code $EXIT_CODE (backup succeeded)"
    # Don't exit on prune failure - backup is more important
fi

log_msg "Flux Local Snapshot Complete."
exit 0

