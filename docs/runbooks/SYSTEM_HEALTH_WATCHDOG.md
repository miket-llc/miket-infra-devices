# System Health Watchdog Documentation

## Overview

The System Health Watchdog is an automated monitoring and recovery service for motoko that detects and resolves common system health issues before they cause service disruption.

## Architecture

### Components

1. **Watchdog Script**: `/usr/local/bin/system-health-watchdog.sh`
   - Bash script that performs health checks
   - Takes automatic corrective actions
   - Logs all actions to `/var/log/system-health-watchdog.log`

2. **Systemd Service**: `system-health-watchdog.service`
   - Oneshot service that runs the watchdog script
   - Resource limited (10% CPU, 100MB RAM)
   - Triggered by timer

3. **Systemd Timer**: `system-health-watchdog.timer`
   - Runs every 5 minutes
   - Starts 5 minutes after boot
   - Persists across reboots

### Deployment

Managed via Ansible role: `ansible/roles/monitoring/`

Deploy with:
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/motoko/deploy-monitoring.yml
```

## Health Checks

### 1. Load Average Monitoring
- **Threshold**: 10.0
- **Action**: Warning log only
- **Rationale**: High load indicates resource contention

### 2. Critical Service Monitoring
Monitors:
- `gdm.service` - GNOME Display Manager
- `tigervnc.service` - VNC server
- `tailscaled.service` - Tailscale VPN
- `docker.service` - Docker daemon

**Action**: Automatic restart if inactive

### 3. Docker Container Crash Loop Detection
- **Detection**: Containers in "restarting" status
- **Action**: Stop container and disable restart policy
- **Rationale**: Prevents resource exhaustion from failing containers

### 4. Tailscale Runaway Detection
- **Threshold**: >200% CPU usage
- **Action**: Restart `tailscaled.service`
- **Rationale**: Tailscale can occasionally consume excessive CPU

### 5. GNOME Shell Error Storm Detection
- **Threshold**: >1000 stack trace errors in 5 minutes
- **Action**: Restart `gdm.service` (max 3 times per hour)
- **Rationale**: GNOME Shell crash loops make system appear frozen

## Operational Details

### State Management

State directory: `/var/lib/system-health-watchdog/`

Files:
- `gnome_restart_count` - Tracks GDM restarts
- `gnome_restart_timestamp` - Last GDM restart time

### Restart Limiting

GNOME restarts are limited to prevent restart loops:
- **Max restarts**: 3 per hour
- **Time window**: 3600 seconds
- **Behavior**: After limit, logs error but doesn't restart

### Logging

All actions logged to:
- `/var/log/system-health-watchdog.log`
- `journalctl -u system-health-watchdog`

Log format:
```
[2025-11-20T08:02:23-05:00] Starting system health check
[2025-11-20T08:02:23-05:00] WARNING: High load average: 8.42
[2025-11-20T08:02:24-05:00] CRITICAL: tailscaled consuming 361% CPU - restarting
[2025-11-20T08:02:27-05:00] System health check complete
```

## Usage

### View Status
```bash
# Check timer status
systemctl status system-health-watchdog.timer

# Check when it will next run
systemctl list-timers system-health-watchdog.timer

# View recent runs
journalctl -u system-health-watchdog -n 50
```

### Manual Execution
```bash
# Run watchdog immediately
sudo systemctl start system-health-watchdog.service

# View results
journalctl -u system-health-watchdog -n 20
```

### View Logs
```bash
# Watchdog log file
sudo tail -f /var/log/system-health-watchdog.log

# System journal
journalctl -u system-health-watchdog -f
```

### Disable/Enable
```bash
# Temporarily disable
sudo systemctl stop system-health-watchdog.timer

# Permanently disable
sudo systemctl disable system-health-watchdog.timer

# Re-enable
sudo systemctl enable --now system-health-watchdog.timer
```

## Maintenance

### Update Watchdog Script

1. Edit source: `ansible/roles/monitoring/files/system-health-watchdog.sh`
2. Deploy via Ansible:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/motoko/deploy-monitoring.yml
   ```

### Adjust Thresholds

Edit the script constants:
```bash
MAX_LOAD_THRESHOLD=10.0
MAX_GNOME_RESTARTS=3
GNOME_RESTART_WINDOW=3600
```

### Change Execution Frequency

Edit `ansible/roles/monitoring/templates/system-health-watchdog.timer.j2`:
```ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=5min  # Change this value
```

## Troubleshooting

### Watchdog Not Running
```bash
# Check timer status
systemctl status system-health-watchdog.timer

# Check for errors
journalctl -u system-health-watchdog.timer -n 50

# Restart timer
sudo systemctl restart system-health-watchdog.timer
```

### Watchdog Taking Wrong Actions
```bash
# Check what triggered the action
sudo cat /var/log/system-health-watchdog.log

# Verify system state
uptime
docker ps -a --filter "status=restarting"
journalctl -t gnome-shell --since "5 minutes ago" | grep -c "Stack trace"
```

### Disable Specific Check

Edit `/usr/local/bin/system-health-watchdog.sh` and comment out the check:
```bash
# check_docker_crashloops  # Disabled temporarily
```

Then reload:
```bash
sudo systemctl daemon-reload
```

## Performance Impact

The watchdog is designed to be lightweight:
- **CPU**: <1% average, 10% max (enforced by systemd)
- **Memory**: <10MB average, 100MB max (enforced by systemd)
- **Disk I/O**: Minimal (log rotation managed by systemd)
- **Execution Time**: ~2-5 seconds per run

## Security Considerations

- Runs as root (required for service management)
- Script is owned by root:root with mode 0755
- State directory is root:root with mode 0755
- No network access required
- No external dependencies

## Related Documentation

- [Motoko Frozen Screen Recovery Runbook](./MOTOKO_FROZEN_SCREEN_RECOVERY.md)
- [Motoko Headless Laptop Setup](./MOTOKO_HEADLESS_LAPTOP_SETUP.md)
- [Monitoring Role Source](../../ansible/roles/monitoring/)

## Version History

### v1.0 (2025-11-20)
- Initial implementation
- Basic health checks for GDM, TigerVNC, Tailscale, Docker
- Docker crash loop detection
- Tailscale runaway detection
- GNOME Shell error storm detection
- Restart limiting for GDM




