#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# space-mirror.sh
# 1:1 Mirror of /space to B2
# Per DATA_LIFECYCLE_SPEC.md

set -euo pipefail

# Secrets (retrieved via Ansible/Environment from Azure Key Vault)
# B2_APPLICATION_KEY_ID / B2_APPLICATION_KEY (from /etc/miket/storage-credentials.env)

SOURCE="/space"
# Use backend notation so rclone can operate without a named remote in rclone.conf
DEST=":b2:miket-space-mirror"
LOG_FILE="/var/log/space-mirror.log"

# Validate required credentials
if [[ -z "${B2_APPLICATION_KEY_ID:-}" ]] || [[ -z "${B2_APPLICATION_KEY:-}" ]]; then
    echo "[$(date)] ERROR: B2 credentials missing from environment" | tee -a "$LOG_FILE"
    echo "[$(date)] Run: ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko" | tee -a "$LOG_FILE"
    exit 1
fi

# Rclone Configuration (environment based for safety)
export RCLONE_B2_HARD_DELETE=true
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

# Function to log and output
log_and_output() {
    echo "$*" | tee -a "$LOG_FILE"
}

log_and_output "[$(date)] Starting Space Mirror..."
log_and_output "[$(date)] Source: $SOURCE"
log_and_output "[$(date)] Destination: $DEST"

# Run rclone with progress output
# Use tee to both log to file AND show on stdout/stderr so systemd can capture it
if rclone sync "$SOURCE" "$DEST" \
    --fast-list \
    --transfers 16 \
    --track-renames \
    --progress \
    --log-file="$LOG_FILE" \
    --log-level=INFO \
    2>&1 | tee -a "$LOG_FILE"; then
    log_and_output "[$(date)] Space Mirror Complete."
    exit 0
else
    EXIT_CODE=${PIPESTATUS[0]}
    log_and_output "[$(date)] Space Mirror FAILED with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
