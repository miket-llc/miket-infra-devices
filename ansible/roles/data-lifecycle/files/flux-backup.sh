#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# flux-backup.sh
# Encrypted, deduplicated backup of /flux to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# Secrets (retrieved via Ansible/Environment from Azure Key Vault)
# RESTIC_PASSWORD
# B2_ACCOUNT_ID
# B2_ACCOUNT_KEY

SOURCE="/flux"
REPO="b2:miket-backups-restic:flux"
LOG_FILE="/var/log/flux-backup.log"

# Validate required credentials
if [[ -z "${RESTIC_PASSWORD:-}" ]] || [[ -z "${B2_ACCOUNT_ID:-}" ]] || [[ -z "${B2_ACCOUNT_KEY:-}" ]]; then
    echo "[$(date)] ERROR: Restic credentials missing from environment" | tee -a "$LOG_FILE"
    echo "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko" | tee -a "$LOG_FILE"
    exit 1
fi

# Function to log and output
log_and_output() {
    echo "$*" | tee -a "$LOG_FILE"
}

log_and_output "[$(date)] Starting Flux Critical Backup..."

# Initialize if repo doesn't exist (idempotent-ish)
if ! restic -r "$REPO" snapshots >/dev/null 2>&1; then
    if ! restic -r "$REPO" init >> "$LOG_FILE" 2>&1; then
        EXIT_CODE=$?
        echo "[$(date)] ERROR: Failed to initialize restic repository (exit code: $EXIT_CODE)" >> "$LOG_FILE"
        exit $EXIT_CODE
    fi
fi

# Backup
if restic -r "$REPO" backup "$SOURCE" \
    --verbose \
    --exclude-file=/flux/.backup-exclude \
    2>&1 | tee -a "$LOG_FILE"; then
    log_and_output "[$(date)] Backup completed successfully"
else
    EXIT_CODE=${PIPESTATUS[0]}
    log_and_output "[$(date)] ERROR: Backup failed with exit code $EXIT_CODE"
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

