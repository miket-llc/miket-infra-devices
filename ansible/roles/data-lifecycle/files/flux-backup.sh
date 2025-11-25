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

echo "[$(date)] Starting Flux Critical Backup..." >> "$LOG_FILE"

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
    >> "$LOG_FILE" 2>&1; then
    echo "[$(date)] Backup completed successfully" >> "$LOG_FILE"
else
    EXIT_CODE=$?
    echo "[$(date)] ERROR: Backup failed with exit code $EXIT_CODE" >> "$LOG_FILE"
    exit $EXIT_CODE
fi

# Prune (Retention Policy)
if restic -r "$REPO" forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --prune \
    >> "$LOG_FILE" 2>&1; then
    echo "[$(date)] Prune completed successfully" >> "$LOG_FILE"
else
    EXIT_CODE=$?
    echo "[$(date)] WARNING: Prune failed with exit code $EXIT_CODE (backup succeeded)" >> "$LOG_FILE"
    # Don't exit on prune failure - backup is more important
fi

echo "[$(date)] Flux Critical Backup Complete." >> "$LOG_FILE"
exit 0

