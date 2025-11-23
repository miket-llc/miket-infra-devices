#!/bin/bash
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
    echo "Error: Local restic password file missing at $PASS_FILE"
    exit 1
fi

echo "[$(date)] Starting Flux Local Snapshot..." >> "$LOG_FILE"

# Initialize local repo if needed
if [[ ! -d "$REPO/data" ]]; then
    restic -r "$REPO" init --password-file "$PASS_FILE"
fi

# Backup
restic -r "$REPO" backup "$SOURCE" \
    --password-file "$PASS_FILE" \
    --exclude-file=/flux/.backup-exclude \
    >> "$LOG_FILE" 2>&1

# Prune (Short-term retention)
restic -r "$REPO" forget \
    --password-file "$PASS_FILE" \
    --keep-hourly 24 \
    --keep-daily 7 \
    --prune \
    >> "$LOG_FILE" 2>&1

echo "[$(date)] Flux Local Snapshot Complete." >> "$LOG_FILE"

