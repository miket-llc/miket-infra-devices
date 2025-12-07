#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# Background /space sync script with resume support
# Usage: ./space-sync-background.sh [bulk|delta]

set -euo pipefail

SYNC_MODE="${1:-bulk}"
LOG_DIR="/var/log/space-migration"
LOG_FILE="${LOG_DIR}/space-sync-$(date +%Y%m%d-%H%M%S).log"
PID_FILE="${LOG_DIR}/space-sync.pid"
STATUS_FILE="${LOG_DIR}/space-sync-status.json"

# Create log directory
mkdir -p "$LOG_DIR"

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Sync already running (PID: $OLD_PID)"
        echo "Monitor with: tail -f $LOG_FILE"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Write initial status
cat > "$STATUS_FILE" <<EOF
{
  "mode": "$SYNC_MODE",
  "started": "$(date -Iseconds)",
  "status": "running",
  "log_file": "$LOG_FILE",
  "pid_file": "$PID_FILE"
}
EOF

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
    fi
    if [ $exit_code -eq 0 ]; then
        jq '.status = "completed" | .completed = now' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
    else
        jq '.status = "failed" | .exit_code = '$exit_code' | .failed = now' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
    fi
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Write PID
echo $$ > "$PID_FILE"

echo "============================================" | tee -a "$LOG_FILE"
echo "Starting /space sync: $SYNC_MODE mode" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "PID: $$" | tee -a "$LOG_FILE"
echo "Started: $(date)" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Build rsync command
SOURCE="/space/"
TARGET="mdt@akira.pangolin-vega.ts.net:/space/"

RSYNC_OPTS=(
    --archive
    --hard-links
    --compress
    --partial
    --partial-dir=.rsync-partial
    --progress
    --human-readable
    --stats
    --itemize-changes
    --log-file="$LOG_FILE"
    --exclude="_ops/logs/**"
    --exclude="_ops/tmp/**"
    --exclude="*.tmp"
    --exclude="*.temp"
    --exclude="*.swp"
    --exclude="*.lock"
    --exclude=".DS_Store"
    --exclude="Thumbs.db"
    --exclude=".rsync-partial"
)

if [ "$SYNC_MODE" = "bulk" ]; then
    RSYNC_OPTS+=(--delete --delete-excluded)
elif [ "$SYNC_MODE" = "delta" ]; then
    RSYNC_OPTS+=(--delete --update)
fi

# Run rsync
echo "Running rsync..." | tee -a "$LOG_FILE"
echo "Command: rsync ${RSYNC_OPTS[*]} $SOURCE $TARGET" | tee -a "$LOG_FILE"

if rsync "${RSYNC_OPTS[@]}" "$SOURCE" "$TARGET" 2>&1 | tee -a "$LOG_FILE"; then
    echo "============================================" | tee -a "$LOG_FILE"
    echo "Sync completed successfully" | tee -a "$LOG_FILE"
    echo "Completed: $(date)" | tee -a "$LOG_FILE"
    echo "============================================" | tee -a "$LOG_FILE"
    exit 0
else
    EXIT_CODE=$?
    echo "============================================" | tee -a "$LOG_FILE"
    echo "Sync failed with exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
    echo "Failed: $(date)" | tee -a "$LOG_FILE"
    echo "Sync can be resumed by running this script again" | tee -a "$LOG_FILE"
    echo "============================================" | tee -a "$LOG_FILE"
    exit $EXIT_CODE
fi

