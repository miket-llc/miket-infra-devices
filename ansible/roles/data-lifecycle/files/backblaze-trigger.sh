#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# backblaze-trigger.sh
# Manual trigger script for Backblaze backup services

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
FOLLOW_LOGS=false

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] [SERVICE]

Manually trigger Backblaze backup services on motoko.

Services:
  flux-backup    - Backup /flux to Backblaze B2 (restic)
  space-mirror   - Mirror /space to Backblaze B2 (rclone)
  all            - Trigger both services sequentially

Options:
  -f, --follow   - Follow logs in real-time after starting
  -s, --status   - Show current status only (don't trigger)
  -h, --help     - Show this help message

Examples:
  $SCRIPT_NAME flux-backup
  $SCRIPT_NAME --follow space-mirror
  $SCRIPT_NAME --status flux-backup
  $SCRIPT_NAME all
EOF
    exit 1
}

show_status() {
    local service=$1
    local log_file=$2
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Service: $service"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show systemd status
    if systemctl is-active --quiet "$service.service"; then
        echo "Status: ✓ ACTIVE (running now)"
    elif systemctl is-failed --quiet "$service.service"; then
        echo "Status: ✗ FAILED"
    else
        echo "Status: ○ INACTIVE"
    fi
    
    # Show last run info
    if systemctl list-units --type=service --state=inactive | grep -q "$service.service"; then
        echo "Last run: $(systemctl show "$service.service" -p ActiveEnterTimestamp --value 2>/dev/null || echo 'Never')"
    fi
    
    # Show timer info
    if systemctl list-timers --all | grep -q "$service.timer"; then
        echo ""
        echo "Timer status:"
        systemctl list-timers "$service.timer" --no-pager | tail -n +2 || true
    fi
    
    # Show recent log entries
    if [ -f "$log_file" ]; then
        echo ""
        echo "Recent log entries (last 5 lines):"
        echo "──────────────────────────────────────────────────────────────────────────"
        tail -n 5 "$log_file" 2>/dev/null | sed 's/^/  /' || echo "  (no log entries yet)"
    else
        echo ""
        echo "Log file: $log_file (not found yet)"
    fi
    
    # Show journalctl recent entries
    echo ""
    echo "Recent systemd journal entries:"
    echo "──────────────────────────────────────────────────────────────────────────"
    journalctl -u "$service.service" -n 5 --no-pager 2>/dev/null | sed 's/^/  /' || echo "  (no journal entries)"
    echo ""
}

follow_logs() {
    local service=$1
    local log_file=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "LIVE LOG OUTPUT (Ctrl+C to stop following, service will continue)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Show what we have so far
    if [ -f "$log_file" ]; then
        echo "Current log file contents:"
        echo "──────────────────────────────────────────────────────────────────────────"
        tail -n 30 "$log_file" 2>/dev/null || echo "  (log file empty)"
        echo ""
    fi
    
    echo "Recent journal entries:"
    echo "──────────────────────────────────────────────────────────────────────────"
    journalctl -u "$service.service" -n 20 --no-pager 2>/dev/null || echo "  (no entries)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Following NEW entries (live stream)..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Follow both journalctl and log file
    # Use a timestamp to only show new entries
    local since_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Follow journalctl with new entries
    journalctl -u "$service.service" -f --since "$since_time" --no-pager 2>/dev/null &
    local journal_pid=$!
    
    # Also follow log file if it exists
    if [ -f "$log_file" ]; then
        tail -f "$log_file" 2>/dev/null &
        local tail_pid=$!
    fi
    
    # Wait for journalctl (primary source)
    wait $journal_pid 2>/dev/null || true
    
    # Clean up tail if it was started
    [ -n "${tail_pid:-}" ] && kill $tail_pid 2>/dev/null || true
}

trigger_service() {
    local service=$1
    local description=$2
    local log_file=$3
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Triggering: $description"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Service: $service.service"
    echo "Log file: $log_file"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Check if already running
    if systemctl is-active --quiet "$service.service"; then
        echo "⚠️  Service is already running!"
        echo "   Current status:"
        systemctl status "$service.service" --no-pager -l | head -n 10 || true
        echo ""
        read -p "Do you want to wait for it to finish? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Waiting for service to complete..."
            systemctl status "$service.service" --wait --no-pager || true
            return 0
        else
            echo "Skipping (service already running)"
            return 0
        fi
    fi
    
    # Start the service
    if systemctl start "$service.service"; then
        echo "✓ Service started successfully"
        echo ""
        
        # Wait a moment for it to actually start
        sleep 2
        
        # Show current status
        echo "Current service status:"
        echo "──────────────────────────────────────────────────────────────────────────"
        systemctl status "$service.service" --no-pager -l || true
        echo ""
        
        # Check if it's still running (oneshot services finish quickly)
        if systemctl is-active --quiet "$service.service"; then
            echo "Service is currently running..."
        elif systemctl is-failed --quiet "$service.service"; then
            echo "⚠️  Service FAILED!"
            echo ""
            echo "Error output:"
            journalctl -u "$service.service" -n 50 --no-pager || true
            return 1
        else
            echo "Service completed (oneshot services finish quickly)"
            echo ""
            echo "Final status:"
            systemctl status "$service.service" --no-pager -l | tail -n 20 || true
        fi
        
        # Follow logs if requested
        if [ "$FOLLOW_LOGS" = true ]; then
            follow_logs "$service" "$log_file"
        else
            echo ""
            echo "Recent log output:"
            echo "──────────────────────────────────────────────────────────────────────────"
            if [ -f "$log_file" ]; then
                tail -n 20 "$log_file" 2>/dev/null || echo "  (log file empty or not readable)"
            else
                echo "  (log file not created yet)"
            fi
            echo ""
            echo "Recent journal entries:"
            echo "──────────────────────────────────────────────────────────────────────────"
            journalctl -u "$service.service" -n 20 --no-pager 2>/dev/null || echo "  (no journal entries)"
            echo ""
            echo "To follow logs in real-time:"
            echo "  journalctl -u $service.service -f"
            echo "  tail -f $log_file"
        fi
        
        return 0
    else
        echo "✗ Failed to start service" >&2
        echo ""
        echo "Error details:"
        systemctl status "$service.service" --no-pager -l || true
        journalctl -u "$service.service" -n 30 --no-pager || true
        return 1
    fi
}

# Parse arguments
SHOW_STATUS_ONLY=false
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW_LOGS=true
            shift
            ;;
        -s|--status)
            SHOW_STATUS_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        flux-backup|space-mirror|all)
            SERVICE=$1
            shift
            ;;
        *)
            echo "Error: Unknown option or service '$1'" >&2
            echo ""
            usage
            ;;
    esac
done

if [ -z "$SERVICE" ] && [ "$SHOW_STATUS_ONLY" = false ]; then
    echo "Error: Service name required" >&2
    echo ""
    usage
fi

EXIT_CODE=0

# Handle status-only mode
if [ "$SHOW_STATUS_ONLY" = true ]; then
    if [ -z "$SERVICE" ] || [ "$SERVICE" = "all" ]; then
        show_status "flux-backup" "/var/log/flux-backup.log"
        echo ""
        show_status "space-mirror" "/var/log/space-mirror.log"
    else
        case "$SERVICE" in
            flux-backup)
                show_status "flux-backup" "/var/log/flux-backup.log"
                ;;
            space-mirror)
                show_status "space-mirror" "/var/log/space-mirror.log"
                ;;
        esac
    fi
    exit 0
fi

# Handle service triggering
case "$SERVICE" in
    flux-backup)
        trigger_service "flux-backup" "Flux Backup to Backblaze B2" "/var/log/flux-backup.log" || EXIT_CODE=1
        ;;
    space-mirror)
        trigger_service "space-mirror" "Space Mirror to Backblaze B2" "/var/log/space-mirror.log" || EXIT_CODE=1
        ;;
    all)
        trigger_service "flux-backup" "Flux Backup to Backblaze B2" "/var/log/flux-backup.log" || EXIT_CODE=1
        echo ""
        echo "Waiting 5 seconds before starting next service..."
        sleep 5
        echo ""
        trigger_service "space-mirror" "Space Mirror to Backblaze B2" "/var/log/space-mirror.log" || EXIT_CODE=1
        ;;
esac

exit $EXIT_CODE

