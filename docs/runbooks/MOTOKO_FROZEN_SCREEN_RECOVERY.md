# Motoko Frozen Screen Recovery Runbook

## Status: ACTIVE
**Last Updated:** 2025-11-20  
**Maintainer:** Chief Device Architect

## Problem Description

Motoko's main screen appears frozen or unresponsive when accessed via VNC. This can be caused by:
1. GNOME Shell crash loops
2. Tailscale runaway CPU consumption
3. Docker containers in crash loops
4. System resource exhaustion

## Root Causes Identified (2025-11-20 Incident)

### Primary Issues
1. **MCP containers crash-looping**: 10+ containers constantly restarting
2. **Tailscale runaway**: 361% CPU usage due to excessive connection churn
3. **GNOME Shell error storm**: 420K+ stack trace errors per hour
4. **System resource exhaustion**: Load average >8.0, memory pressure, journal overload

### Contributing Factors
- No resource limits on Docker containers
- No health monitoring or automatic recovery
- Journal flooded with GNOME Shell errors
- Cascading failures causing mutual degradation

## Automated Recovery

A **System Health Watchdog** has been deployed that runs every 5 minutes and automatically:
- Detects and stops crash-looping containers
- Restarts Tailscale if CPU usage >200%
- Restarts GDM if GNOME Shell error rate >1000/5min
- Monitors critical services (GDM, TigerVNC, Docker, Tailscale)

### Watchdog Details
- **Service**: `system-health-watchdog.service`
- **Timer**: `system-health-watchdog.timer` (every 5 minutes)
- **Script**: `/usr/local/bin/system-health-watchdog.sh`
- **Logs**: `/var/log/system-health-watchdog.log`
- **State**: `/var/lib/system-health-watchdog/`

## Manual Recovery Steps

### Quick Recovery (Ansible)

From motoko or any machine with Ansible access:

```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/motoko/recover-frozen-display.yml
```

This playbook automatically:
1. Stops crash-looping containers
2. Restarts Tailscale if needed
3. Restarts GDM if GNOME is in error storm
4. Restarts TigerVNC
5. Verifies all critical services

### Manual Recovery (SSH)

If Ansible is not available, SSH to motoko and run:

```bash
# 1. Check system status
uptime
top -b -n 1 | head -20

# 2. Stop crash-looping containers
docker ps -a --filter "status=restarting" --format "{{.Names}}" | while read container; do
    docker stop "$container"
    docker update --restart=no "$container"
done

# 3. Check and restart Tailscale if needed
ps aux | grep tailscaled
# If CPU is >200%, restart:
sudo systemctl restart tailscaled

# 4. Check GNOME Shell errors
journalctl -t gnome-shell --since "5 minutes ago" --no-pager | grep -c "Stack trace"
# If >1000 errors, restart GDM:
sudo systemctl restart gdm.service

# 5. Restart TigerVNC
sudo systemctl restart tigervnc.service

# 6. Verify services
systemctl status gdm tigervnc tailscaled docker
```

### Emergency Recovery (Physical Access)

If SSH is unavailable:

1. **Connect physical keyboard/monitor** or use existing HDMI monitor
2. **Press Ctrl+Alt+F3** to switch to TTY3
3. **Login** as mdt
4. **Run recovery commands** as above
5. **Switch back** to GUI with Ctrl+Alt+F1

## Prevention Measures Implemented

### 1. System Health Watchdog
- **Deployed**: `/usr/local/bin/system-health-watchdog.sh`
- **Monitors**: Load average, service status, GNOME Shell health, Docker containers, Tailscale CPU
- **Actions**: Automatic service restarts, container stops, resource limit enforcement
- **Schedule**: Every 5 minutes via systemd timer

### 2. Docker Logging Limits
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```
Prevents disk/memory exhaustion from container logs.

### 3. MCP Container Management
All crash-looping MCP containers have been:
- Stopped
- Configured with `--restart=no` to prevent automatic restarts
- Documented for manual investigation

### 4. Resource Limits
Watchdog service itself is limited:
- CPUQuota=10%
- MemoryMax=100M

## Monitoring

### Check Watchdog Status
```bash
systemctl status system-health-watchdog.timer
journalctl -u system-health-watchdog -f
```

### View Watchdog Logs
```bash
tail -f /var/log/system-health-watchdog.log
```

### Check for Issues
```bash
# Load average
uptime

# Top CPU consumers
top -b -n 1 -o +%CPU | head -20

# Crash-looping containers
docker ps -a --filter "status=restarting"

# GNOME Shell errors
journalctl -t gnome-shell --since "5 minutes ago" --no-pager | grep -c "Stack trace"

# Tailscale CPU
ps aux | grep tailscaled
```

## Architecture References

### IaC/CaC Implementation
- **Watchdog Role**: `ansible/roles/monitoring/`
- **Deployment Playbook**: `ansible/playbooks/motoko/deploy-monitoring.yml`
- **Recovery Playbook**: `ansible/playbooks/motoko/recover-frozen-display.yml`

All configurations are managed as code and can be redeployed idempotently.

## Incident Log

### 2025-11-20 - Initial Incident and Resolution
**Symptoms**: Main screen frozen, VNC unresponsive  
**Load Average**: 8.42 (4 core system)  
**Root Causes**:
- 10 MCP containers crash-looping
- **Tailscale at 361% CPU** - Connection tracking storm
  - Tailscale attempting to track non-peer connections (external IPs like 3.171.61.x:80)
  - Thousands of failed `connect()` syscalls (exit codes -115 EINPROGRESS, -99 EADDRNOTAVAIL)
  - "open-conn-track: timeout opening; no associated peer node" errors repeating
  - Likely caused by system routing/iptables configuration causing Tailscale to intercept non-Tailscale traffic
  - High CPU from spinning on connection attempts that don't belong to Tailscale network
- **GNOME Shell error storm: Pop Shell extension stuck in infinite loop**
  - Pop Shell (`pop-shell@system76.com`) encountered buggy X11 client sending incorrect window timestamps
  - Extension repeatedly tried to process bad events → 10,000+ stack traces in 5 minutes
  - Triggered by VNC or remote client sending inaccurate `_NET_ACTIVE_WINDOW` timestamps
- systemd-journal at 100% CPU (flooded by error logs)

**Resolution**:
1. Stopped crash-looping MCP containers
2. Restarted Tailscale
3. Restarted GDM (GNOME) - cleared Pop Shell error loop
4. Restarted TigerVNC
5. Configured Docker logging limits
6. Deployed system health watchdog

**Time to Recover**: ~5 minutes  
**Long-term Prevention**: Automated monitoring and recovery deployed

### 2025-11-20 - Watchdog Auto-Recovery
**Time**: 08:02:27 EST  
**Trigger**: Watchdog detected GNOME Shell error storm (10,000 errors in 5 minutes)  
**Action**: Automatic GDM restart  
**Result**: System recovered, Pop Shell errors cleared  
**Note**: Watchdog syntax errors fixed (numeric value sanitization)

## Related Documentation
- [Motoko Headless Laptop Setup](./MOTOKO_HEADLESS_LAPTOP_SETUP.md)
- [VNC Connection Instructions](../VNC_CONNECTION_INSTRUCTIONS.md)
- [System Health Watchdog Code](../../ansible/roles/monitoring/)

## Escalation

If automated and manual recovery fails:
1. **Reboot motoko**: `sudo reboot`
2. **Check for hardware issues**: Monitor temperatures, disk health
3. **Review recent changes**: Check git log for recent deployments
4. **Disable problematic services**: If specific service consistently causes issues

## Future Improvements

1. **Prometheus/Grafana monitoring**: Real-time dashboards for system health
2. **Alerting**: PagerDuty/email alerts for critical conditions
3. **MCP container stability**: Investigate why MCP containers crash
4. **Tailscale optimization**: Understand why Tailscale can runaway
5. **GNOME Shell debugging**: Identify root cause of crash loops

