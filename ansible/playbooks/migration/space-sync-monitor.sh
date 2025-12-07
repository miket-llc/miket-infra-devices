#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# Monitor /space sync progress
# Usage: ./space-sync-monitor.sh [--follow]

LOG_DIR="/var/log/space-migration"
PID_FILE="${LOG_DIR}/space-sync.pid"
STATUS_FILE="${LOG_DIR}/space-sync-status.json"

if [ ! -f "$PID_FILE" ]; then
    echo "No sync process found (PID file missing)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Sync process not running (PID: $PID)"
    if [ -f "$STATUS_FILE" ]; then
        echo "Last status:"
        cat "$STATUS_FILE" | jq .
    fi
    exit 1
fi

# Get status
if [ -f "$STATUS_FILE" ]; then
    echo "Sync Status:"
    cat "$STATUS_FILE" | jq .
    echo ""
fi

# Find log file
LATEST_LOG=$(ls -t "${LOG_DIR}"/space-sync-*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo "No log file found"
    exit 1
fi

echo "Log file: $LATEST_LOG"
echo "Process: PID $PID"
echo ""

if [ "${1:-}" = "--follow" ]; then
    echo "Following log (Ctrl+C to stop)..."
    tail -f "$LATEST_LOG"
else
    echo "Last 50 lines:"
    tail -50 "$LATEST_LOG"
    echo ""
    echo "To follow live: $0 --follow"
fi

