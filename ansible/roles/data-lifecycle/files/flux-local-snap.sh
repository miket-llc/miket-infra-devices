#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# flux-local-snap.sh
# Hourly local snapshots of /flux
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

SOURCE="/flux"
REPO="/space/snapshots/flux-local"
PASS_FILE="/root/.restic-local-pass" # Local only password
LOG_FILE="/var/log/flux-local-snap.log"

# Ensure password file exists
if [[ ! -f "$PASS_FILE" ]]; then
    echo "[$(date)] ERROR: Local restic password file missing at $PASS_FILE" | tee -a "$LOG_FILE"
    echo "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-lifecycle.yml" | tee -a "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Starting Flux Local Snapshot..." >> "$LOG_FILE"

# Initialize local repo if needed
if [[ ! -d "$REPO/data" ]]; then
    if ! restic -r "$REPO" init --password-file "$PASS_FILE" >> "$LOG_FILE" 2>&1; then
        EXIT_CODE=$?
        echo "[$(date)] ERROR: Failed to initialize restic repository (exit code: $EXIT_CODE)" >> "$LOG_FILE"
        exit $EXIT_CODE
    fi
fi

# Backup
if restic -r "$REPO" backup "$SOURCE" \
    --password-file "$PASS_FILE" \
    --exclude-file=/flux/.backup-exclude \
    >> "$LOG_FILE" 2>&1; then
    echo "[$(date)] Backup completed successfully" >> "$LOG_FILE"
else
    EXIT_CODE=$?
    echo "[$(date)] ERROR: Backup failed with exit code $EXIT_CODE" >> "$LOG_FILE"
    exit $EXIT_CODE
fi

# Prune (Short-term retention)
if restic -r "$REPO" forget \
    --password-file "$PASS_FILE" \
    --keep-hourly 24 \
    --keep-daily 7 \
    --prune \
    >> "$LOG_FILE" 2>&1; then
    echo "[$(date)] Prune completed successfully" >> "$LOG_FILE"
else
    EXIT_CODE=$?
    echo "[$(date)] WARNING: Prune failed with exit code $EXIT_CODE (backup succeeded)" >> "$LOG_FILE"
    # Don't exit on prune failure - backup is more important
fi

echo "[$(date)] Flux Local Snapshot Complete." >> "$LOG_FILE"
exit 0

