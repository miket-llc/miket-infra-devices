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

check_container_crashloops() {
    # Find containers that are restarting constantly
    # Platform Standard: Podman-only (docker command maps to podman via podman-docker)
    local crashloop_containers
    crashloop_containers=$(podman ps -a --filter "status=restarting" --format "{{.Names}}" 2>/dev/null || echo "")
    if [[ -n "$crashloop_containers" ]]; then
        log "WARNING: Crash-looping containers detected: $crashloop_containers"
        for container in $crashloop_containers; do
            log "Stopping crash-looping container: $container"
            podman stop "$container" 2>/dev/null || true
            podman update --restart=no "$container" 2>/dev/null || true
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

check_btrfs_health() {
    # Check btrfs device stats for errors on /podman
    # Incident 2025-12-04: NVMe medium errors caused btrfs RO remount
    local btrfs_mounts
    btrfs_mounts=$(findmnt -t btrfs -n -o TARGET 2>/dev/null || echo "")
    
    for mount in $btrfs_mounts; do
        # Check if mounted read-only unexpectedly
        local mount_opts
        mount_opts=$(findmnt -n -o OPTIONS "$mount" 2>/dev/null || echo "")
        if echo "$mount_opts" | grep -q "^ro,"; then
            log "CRITICAL: btrfs $mount is mounted read-only unexpectedly!"
        fi
        
        # Check device stats for errors
        local stats
        stats=$(btrfs device stats "$mount" 2>/dev/null || echo "")
        
        local write_errors read_errors corruption_errors
        write_errors=$(echo "$stats" | grep write_io_errs | awk '{print $2}' | head -1 || echo "0")
        read_errors=$(echo "$stats" | grep read_io_errs | awk '{print $2}' | head -1 || echo "0")
        corruption_errors=$(echo "$stats" | grep corruption_errs | awk '{print $2}' | head -1 || echo "0")
        
        if [[ "${write_errors:-0}" -gt 0 ]] || [[ "${read_errors:-0}" -gt 0 ]] || [[ "${corruption_errors:-0}" -gt 0 ]]; then
            log "CRITICAL: btrfs $mount has device errors! write=$write_errors read=$read_errors corruption=$corruption_errors"
        fi
    done
}

check_nvme_health() {
    # Check NVMe SMART data for concerning metrics
    # Incident 2025-12-04: 426 media errors on NVMe caused btrfs issues
    local nvme_devices
    nvme_devices=$(ls /dev/nvme[0-9]n[0-9] 2>/dev/null || echo "")
    
    for device in $nvme_devices; do
        if command -v nvme &>/dev/null; then
            local smart_log
            smart_log=$(nvme smart-log "$device" 2>/dev/null || echo "")
            
            # Check media errors
            local media_errors
            media_errors=$(echo "$smart_log" | grep "media_errors" | awk -F: '{print $2}' | tr -d ' ' || echo "0")
            if [[ "${media_errors:-0}" -gt 100 ]]; then
                log "WARNING: NVMe $device has $media_errors media errors - consider replacement"
            fi
            
            # Check critical warning
            local critical_warning
            critical_warning=$(echo "$smart_log" | grep "critical_warning" | awk -F: '{print $2}' | tr -d ' ' || echo "0")
            if [[ "${critical_warning:-0}" -gt 0 ]]; then
                log "CRITICAL: NVMe $device has critical_warning flag set!"
            fi
            
            # Check temperature
            local temperature
            temperature=$(echo "$smart_log" | grep "^temperature" | awk -F: '{print $2}' | awk '{print $1}' || echo "0")
            if [[ "${temperature:-0}" -gt 75 ]]; then
                log "WARNING: NVMe $device temperature is ${temperature}°C - running hot"
            fi
        fi
    done
}

check_dmesg_errors() {
    # Check dmesg for recent btrfs or nvme errors
    local recent_errors
    recent_errors=$(dmesg --time-format iso 2>/dev/null | tail -100 | grep -iE "(btrfs.*(error|readonly)|nvme.*error|medium error)" | tail -5 || echo "")
    
    if [[ -n "$recent_errors" ]]; then
        log "WARNING: Recent kernel errors detected:"
        echo "$recent_errors" | while read -r line; do
            log "  $line"
        done
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
    
    # Check critical services (only if they exist on this system)
    for service in tailscaled.service podman.socket; do
        if systemctl list-unit-files "$service" &>/dev/null; then
            if ! check_service "$service"; then
                log "CRITICAL: $service is down - attempting restart"
                systemctl restart "$service" || log "ERROR: Failed to restart $service"
            fi
        fi
    done
    
    # Check optional GUI services only if installed
    for service in gdm.service tigervnc.service; do
        if systemctl list-unit-files "$service" &>/dev/null && systemctl is-enabled "$service" &>/dev/null; then
            if ! check_service "$service"; then
                log "WARNING: $service is not active (optional service)"
            fi
        fi
    done
    
    # Check for specific issues
    check_container_crashloops
    check_tailscale_runaway
    
    # Check storage health (btrfs, NVMe)
    # Added after incident 2025-12-04: NVMe errors caused /podman RO remount
    check_btrfs_health
    check_nvme_health
    check_dmesg_errors
    
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

