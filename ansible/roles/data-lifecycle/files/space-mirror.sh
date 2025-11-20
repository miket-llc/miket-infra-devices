#!/bin/bash
# space-mirror.sh
# 1:1 Mirror of /space to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# Secrets (retrieved via Ansible/Environment)
# B2_APPLICATION_KEY_ID
# B2_APPLICATION_KEY

SOURCE="/space"
DEST="b2:miket-space-mirror"
LOG_FILE="/var/log/space-mirror.log"

# Rclone Configuration (environment based for safety)
export RCLONE_B2_HARD_DELETE=true

echo "[$(date)] Starting Space Mirror..." >> "$LOG_FILE"

rclone sync "$SOURCE" "$DEST" \
    --fast-list \
    --transfers 16 \
    --track-renames \
    --progress \
    --log-file="$LOG_FILE" \
    --log-level=INFO

echo "[$(date)] Space Mirror Complete." >> "$LOG_FILE"

