#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# System Health Watchdog for motoko
# Monitors critical services and takes corrective action
# Part of miket-infra-devices monitoring role

set -euo pipefail

LOG_FILE="/var/log/system-health-watchdog.log"
MAX_LOAD_THRESHOLD=10.0
MAX_GNOME_RESTARTS=3
GNOME_RESTART_WINDOW=3600  # 1 hour

# State tracking
STATE_DIR="/var/lib/system-health-watchdog"
mkdir -p "$STATE_DIR"

log() {
    echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

check_service() {
    local service=$1
    if ! systemctl is-active --quiet "$service"; then
        log "WARNING: $service is not active"
        return 1
    fi
    return 0
}

get_load_average() {
    awk '{print $1}' /proc/loadavg
}

check_gnome_shell_errors() {
    # Check if gnome-shell is spamming errors
    local error_count
    error_count=$(journalctl -t gnome-shell --since "5 minutes ago" --no-pager 2>/dev/null | grep -c "Stack trace" || echo "0")
    # Ensure we have a valid number (remove any newlines)
    error_count=$(echo "$error_count" | tr -d '\n' | head -1)
    if [[ ! "$error_count" =~ ^[0-9]+$ ]]; then
        error_count="0"
    fi
    echo "$error_count"
}

check_docker_crashloops() {
    # Find containers that are restarting constantly
    local crashloop_containers
    crashloop_containers=$(docker ps -a --filter "status=restarting" --format "{{.Names}}" 2>/dev/null || echo "")
    if [[ -n "$crashloop_containers" ]]; then
        log "WARNING: Crash-looping containers detected: $crashloop_containers"
        for container in $crashloop_containers; do
            log "Stopping crash-looping container: $container"
            docker stop "$container" 2>/dev/null || true
            docker update --restart=no "$container" 2>/dev/null || true
        done
    fi
}

check_tailscale_runaway() {
    # Check if tailscaled is consuming excessive CPU
    local tailscale_cpu
    tailscale_cpu=$(ps aux | grep '[t]ailscaled' | awk '{print int($3)}' | head -1 | tr -d '\n' || echo "0")
    # Ensure we have a valid number
    if [[ ! "$tailscale_cpu" =~ ^[0-9]+$ ]]; then
        tailscale_cpu="0"
    fi
    if [[ ${tailscale_cpu:-0} -gt 200 ]]; then
        log "CRITICAL: tailscaled consuming ${tailscale_cpu}% CPU - restarting"
        systemctl restart tailscaled
        sleep 5
    fi
}

restart_gnome_if_needed() {
    local error_count=$1
    local restart_count_file="$STATE_DIR/gnome_restart_count"
    local restart_timestamp_file="$STATE_DIR/gnome_restart_timestamp"
    
    # Reset counter if window has passed
    if [[ -f "$restart_timestamp_file" ]]; then
        local last_restart
        last_restart=$(cat "$restart_timestamp_file")
        local current_time
        current_time=$(date +%s)
        if (( current_time - last_restart > GNOME_RESTART_WINDOW )); then
            echo "0" > "$restart_count_file"
        fi
    fi
    
    # Check error threshold
    if [[ $error_count -gt 1000 ]]; then
        local restart_count
        restart_count=$(cat "$restart_count_file" 2>/dev/null || echo "0")
        
        if [[ $restart_count -lt $MAX_GNOME_RESTARTS ]]; then
            log "CRITICAL: GNOME Shell error storm detected ($error_count errors) - restarting GDM"
            systemctl restart gdm.service
            echo "$((restart_count + 1))" > "$restart_count_file"
            date +%s > "$restart_timestamp_file"
            sleep 10
        else
            log "ERROR: GNOME restart limit reached ($MAX_GNOME_RESTARTS in ${GNOME_RESTART_WINDOW}s), not restarting"
        fi
    fi
}

main() {
    log "Starting system health check"
    
    # Check load average
    local load_avg
    load_avg=$(get_load_average)
    if (( $(echo "$load_avg > $MAX_LOAD_THRESHOLD" | bc -l) )); then
        log "WARNING: High load average: $load_avg"
    fi
    
    # Check critical services
    for service in gdm.service tigervnc.service tailscaled.service docker.service; do
        if ! check_service "$service"; then
            log "CRITICAL: $service is down - attempting restart"
            systemctl restart "$service" || log "ERROR: Failed to restart $service"
        fi
    done
    
    # Check for specific issues
    check_docker_crashloops
    check_tailscale_runaway
    
    # Check GNOME Shell health
    local gnome_errors
    gnome_errors=$(check_gnome_shell_errors)
    if [[ $gnome_errors -gt 1000 ]]; then
        log "WARNING: GNOME Shell error storm: $gnome_errors errors in last 5 minutes"
        restart_gnome_if_needed "$gnome_errors"
    fi
    
    log "System health check complete"
}

main "$@"

