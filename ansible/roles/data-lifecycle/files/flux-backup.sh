#!/bin/bash
# flux-backup.sh
# Encrypted, deduplicated backup of /flux to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# Secrets (retrieved via Ansible/Environment)
# RESTIC_PASSWORD
# B2_APPLICATION_KEY_ID
# B2_APPLICATION_KEY

SOURCE="/flux"
REPO="b2:miket-backups-restic:flux"
LOG_FILE="/var/log/flux-backup.log"

echo "[$(date)] Starting Flux Critical Backup..." >> "$LOG_FILE"

# Initialize if repo doesn't exist (idempotent-ish)
restic -r "$REPO" snapshots >/dev/null 2>&1 || restic -r "$REPO" init

# Backup
restic -r "$REPO" backup "$SOURCE" \
    --verbose \
    --exclude-file=/flux/.backup-exclude \
    >> "$LOG_FILE" 2>&1

# Prune (Retention Policy)
restic -r "$REPO" forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --prune \
    >> "$LOG_FILE" 2>&1

echo "[$(date)] Flux Critical Backup Complete." >> "$LOG_FILE"

