#!/bin/bash
# GNOME Health Monitor and Auto-Recovery Script
# Monitors GNOME Shell health and prevents crash loops
# Location: devices/motoko/scripts/gnome-health-monitor.sh

set -euo pipefail

LOG_FILE="/var/log/gnome-health-monitor.log"
DISABLE_EXTENSIONS_FILE="/run/user/1000/gnome-shell-disable-extensions"
MAX_CPU_THRESHOLD=80  # Alert if gnome-shell uses > 80% CPU for sustained period
CHECK_INTERVAL=30     # Check every 30 seconds

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_gnome_shell_health() {
    # Check if gnome-shell is running
    if ! pgrep -u "$USER" gnome-shell > /dev/null; then
        log "WARNING: gnome-shell is not running!"
        return 1
    fi
    
    # Get gnome-shell CPU usage
    local cpu_usage
    cpu_usage=$(ps -u "$USER" -o pid,%cpu,comm | grep gnome-shell | grep -v grep | awk '{print int($2)}' | head -1)
    
    if [ -n "$cpu_usage" ] && [ "$cpu_usage" -gt "$MAX_CPU_THRESHOLD" ]; then
        log "WARNING: gnome-shell CPU usage is high: ${cpu_usage}%"
        return 1
    fi
    
    return 0
}

check_disable_extensions_file() {
    # Check if the problematic disable-extensions file exists
    if [ -f "$DISABLE_EXTENSIONS_FILE" ]; then
        log "CRITICAL: Found gnome-shell-disable-extensions file - removing to prevent crash loop"
        rm -f "$DISABLE_EXTENSIONS_FILE"
        log "SUCCESS: Removed disable-extensions file"
        
        # Check if gnome-shell needs restart
        if ! check_gnome_shell_health; then
            log "INFO: gnome-shell appears unhealthy, but letting it self-recover"
        fi
        
        return 1
    fi
    
    return 0
}

check_extension_errors() {
    # Check recent journal for extension errors
    local error_count
    error_count=$(journalctl --since "2 minutes ago" --no-pager | grep -i "gnome-shell.*error" | wc -l)
    
    if [ "$error_count" -gt 10 ]; then
        log "WARNING: High number of gnome-shell errors detected: $error_count in last 2 minutes"
        return 1
    fi
    
    return 0
}

# Main monitoring loop
log "=== GNOME Health Monitor Started ==="
log "Monitoring interval: ${CHECK_INTERVAL}s"
log "CPU threshold: ${MAX_CPU_THRESHOLD}%"

while true; do
    check_disable_extensions_file || log "INFO: Disable-extensions file was present and removed"
    check_gnome_shell_health || log "INFO: GNOME Shell health check failed"
    check_extension_errors || log "INFO: Extension errors detected"
    
    sleep "$CHECK_INTERVAL"
done


