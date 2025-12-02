# Device Health Check Runbook

**Status:** ACTIVE
**Target:** All managed devices (macOS, Windows, Linux)
**Owner:** Infrastructure Team

## Overview
This runbook describes how to verify the health status of all managed devices in the fleet. Devices are required to report their status to the central storage server (`motoko`) automatically.

## 1. Central Status View

All devices report their status to `/space/devices/<hostname>/<user>/_status.json`.
To check the fleet health, log in to `motoko` and run:

```bash
# Scan all status files and print summary
find /space/devices -name "_status.json" -print0 | xargs -0 -I {} sh -c 'echo "--- {} ---"; cat {}; echo'
```

### Status Schema
```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "device": "hostname",
  "status": "healthy|degraded|error",
  "components": {
    "mounts": { "flux": true, "space": true, "time": true }
  }
}
```

## 2. Troubleshooting by Platform

### macOS (`count-zero`)
- **Mount Status:** `mount | grep .mkt`
- **Logs:** `~/.scripts/mount_shares.log`
- **Sync Logs:** `~/.scripts/oscloud-sync/sync.log`
- **Force Health Check:** Re-run `~/.scripts/mount_shares.sh`

### Windows (`armitage`, `wintermute`)
- **Mount Status:** Check Explorer for X:, S:, T:
- **Logs:** `C:\Scripts\oscloud-sync\sync.log`
- **Force Health Check:** Re-run `C:\Scripts\Map-Drives.ps1`

### Linux (Resilience Nodes - `atom`)
- **Mount Status:** None by design (no CIFS mounts)
- **Logs:** `journalctl -u resilience-health.service`
- **Force Health Check:** `systemctl start resilience-health.service`
- **Note:** Uses SSH-based push to motoko, not local mounts

### Linux (Workstations with autofs)
- **Mount Status:** `mount | grep autofs` and `mount | grep cifs`
- **Logs:** `journalctl -u device-health.service`
- **Force Health Check:** `systemctl start device-health.service`
- **Note:** Shares mount on-demand via autofs, unmount after 5min idle

## 3. Common Issues

### "Degraded" Status
- **Cause:** One or more mounts failed.
- **Fix:** Check network (Tailscale/WiFi), check authentication (Vault/KeyVault).

### Stale Timestamp
- **Cause:** Device hasn't reported in >24h.
- **Fix:** Check if device is powered on. Check if cron/TaskScheduler/Systemd timer is running.

### Missing Status File
- **Cause:** Device never successfully mounted `/space` (or SSH push failed for resilience nodes).
- **Fix:** Critical failure. Device cannot write to server. Troubleshoot network/auth immediately.
- **Exception:** Resilience nodes (atom) may have missing status if motoko is down - this is expected.

### Linux Desktop Freeze After Network Hiccup
- **Cause:** CIFS kernel bug (`cfids_invalidation_worker`) on static fstab mounts.
- **Fix:** SSH in and `sudo systemctl restart gdm`. Then remove CIFS mounts:
  ```bash
  ansible-playbook playbooks/atom/remove-cifs-mounts.yml
  ```
- **Prevention:** Use `mount_shares_linux_autofs` role instead of static mounts.




