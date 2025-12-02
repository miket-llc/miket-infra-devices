#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# flux-backup.sh
# Encrypted, deduplicated backup of /flux to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Secrets (retrieved via Ansible/Environment from Azure Key Vault)
# RESTIC_PASSWORD
# B2_ACCOUNT_ID
# B2_ACCOUNT_KEY

SOURCE="/flux"
REPO="b2:miket-backups-restic:flux"
LOG_DIR="${DATA_LIFECYCLE_LOG_DIR:-/space/_ops/logs/data-lifecycle}"
LOG_FILE="${LOG_DIR}/flux-backup.log"
MARKERS_DIR="${DATA_LIFECYCLE_MARKERS_DIR:-/space/_ops/data-estate/markers}"
MARKER_FILE="${MARKERS_DIR}/restic_cloud.json"
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
    local snapshot_id="${3:-}"
    local temp_file
    temp_file=$(mktemp "${MARKERS_DIR}/.restic_cloud.XXXXXX")
    
    cat > "$temp_file" << EOF
{
  "job": "restic_cloud",
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
    log_and_output "[$(date)] Marker file updated: ${MARKER_FILE}"
}

# =============================================================================
# Credential Validation
# =============================================================================

if [[ -z "${RESTIC_PASSWORD:-}" ]] || [[ -z "${B2_ACCOUNT_ID:-}" ]] || [[ -z "${B2_ACCOUNT_KEY:-}" ]]; then
    log_and_output "[$(date)] ERROR: Restic credentials missing from environment"
    log_and_output "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko"
    exit 1
fi

# =============================================================================
# Main Backup Logic
# =============================================================================

log_and_output "[$(date)] Starting Flux Critical Backup..."
log_and_output "[$(date)] Source: ${SOURCE}"
log_and_output "[$(date)] Repository: ${REPO}"

# Initialize if repo doesn't exist (idempotent-ish)
if ! restic -r "$REPO" snapshots >/dev/null 2>&1; then
    log_and_output "[$(date)] Initializing new restic repository..."
    if ! restic -r "$REPO" init >> "$LOG_FILE" 2>&1; then
        EXIT_CODE=$?
        log_and_output "[$(date)] ERROR: Failed to initialize restic repository (exit code: $EXIT_CODE)"
        exit $EXIT_CODE
    fi
fi

# Backup
BACKUP_OUTPUT=$(mktemp)
if restic -r "$REPO" backup "$SOURCE" \
    --verbose \
    --json \
    --exclude-file=/flux/.backup-exclude \
    2>&1 | tee -a "$LOG_FILE" | tee "$BACKUP_OUTPUT"; then
    
    # Extract snapshot ID from JSON output
    SNAPSHOT_ID=$(grep '"message_type":"summary"' "$BACKUP_OUTPUT" | jq -r '.snapshot_id // empty' 2>/dev/null || echo "")
    rm -f "$BACKUP_OUTPUT"
    
    log_and_output "[$(date)] Backup completed successfully"
    
    # Write success marker ONLY after successful backup
    write_marker "success" "Backup completed successfully" "$SNAPSHOT_ID"
else
    EXIT_CODE=${PIPESTATUS[0]}
    rm -f "$BACKUP_OUTPUT"
    log_and_output "[$(date)] ERROR: Backup failed with exit code $EXIT_CODE"
    # Do NOT update marker on failure - preserve last success timestamp
    exit $EXIT_CODE
fi

# Prune (Retention Policy)
if restic -r "$REPO" forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --prune \
    2>&1 | tee -a "$LOG_FILE"; then
    log_and_output "[$(date)] Prune completed successfully"
else
    EXIT_CODE=${PIPESTATUS[0]}
    log_and_output "[$(date)] WARNING: Prune failed with exit code $EXIT_CODE (backup succeeded)"
    # Don't exit on prune failure - backup is more important
fi

log_and_output "[$(date)] Flux Critical Backup Complete."
exit 0

