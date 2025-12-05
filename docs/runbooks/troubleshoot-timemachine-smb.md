---
document_title: "Troubleshoot Time Machine SMB Connection Issues"
author: "Codex-CA-001"
last_updated: 2025-12-05
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-12-04-timemachine-smb-troubleshooting
  - docs/communications/COMMUNICATION_LOG.md#2025-12-05-usb-device-drift-fix
---

# Troubleshoot Time Machine SMB Connection Issues

**Issue:** Time Machine keeps failing to connect to the `time` volume on motoko.

## Quick Diagnosis

### Option 1: Run Diagnostic Script (Recommended)

Run the diagnostic script on count-zero:
```bash
./scripts/diagnose-timemachine-smb.sh
```

Or from motoko:
```bash
tailscale ssh count-zero 'bash -s' < scripts/diagnose-timemachine-smb.sh
```

### Option 2: Manual Checks

```bash
# Check Time Machine status
tmutil status

# Check Time Machine destinations
tmutil destinationinfo

# Check if Time Machine mount exists
mount | grep -i timemachine

# Check regular SMB mounts
mount | grep motoko
ls ~/.mkt/space ~/.mkt/flux ~/.mkt/time
```

## Common Issues and Fixes

### 1. Stale SMB Mounts

**Symptoms:**
- `ls ~/.mkt/space` shows "Socket is not connected"
- Mounts appear in `mount` but are not accessible
- Time Machine cannot find backup volume

**Root Cause:**
SMB mounts become stale after network interruptions, sleep/wake cycles, or server restarts. The mount appears in the mount table but is not actually connected.

**Fix:**
```bash
# Unmount stale mounts
umount ~/.mkt/flux ~/.mkt/space ~/.mkt/time 2>/dev/null || true

# Remount using the mount script
~/.scripts/mount_shares.sh

# Verify mounts are working
ls ~/.mkt/space ~/.mkt/flux ~/.mkt/time
```

**Prevention:**
The mount script has been updated to automatically detect and remount stale mounts. It tests if mounts are accessible using `ls` before assuming they're working.

### 2. Time Machine Cannot Find Backup Volume

**Symptoms:**
- Time Machine status shows `BackupPhase = FindingBackupVol`
- Backup never progresses past this phase
- No error messages in logs

**Possible Causes:**
1. Time Machine mount is stale (see fix above)
2. Network connectivity issues
3. SMB authentication problems
4. Server-side SMB service issues

**Fix:**
```bash
# Check if Time Machine mount exists and is accessible
TM_MOUNT=$(mount | grep -i "timemachine.*motoko" | awk '{print $3}')
if [ -n "$TM_MOUNT" ]; then
    ls "$TM_MOUNT" || echo "Mount is stale"
fi

# If mount is stale, Time Machine will create a new one automatically
# But you may need to restart Time Machine:
sudo killall backupd

# Or remove and re-add the destination:
tmutil removedestination <DESTINATION_ID>
# Then add via System Settings > Time Machine
```

### 3. Network Connectivity Issues

**Symptoms:**
- Cannot ping motoko
- SMB connections fail
- Time Machine cannot reach server

**Fix:**
```bash
# Check Tailscale status
tailscale status

# Test connectivity
ping -c 3 motoko
ping -c 3 motoko.pangolin-vega.ts.net

# If Tailscale is down, restart it
tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
```

### 4. SMB Credentials Missing or Incorrect

**Symptoms:**
- Time Machine prompts for password repeatedly
- SMB mounts fail with authentication errors
- Secrets file missing or empty

**Fix:**
```bash
# Check if secrets file exists
test -f ~/.mkt/mounts.env && echo "OK" || echo "MISSING"

# If missing, sync from Azure Key Vault (from motoko):
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit count-zero

# Verify credentials are in macOS Keychain
security find-internet-password -s motoko.pangolin-vega.ts.net -a mdt

# If missing, Time Machine will prompt for password on next backup
# Enter credentials when prompted, and macOS will store them in Keychain
```

### 5. Hostname Resolution Issues

**Symptoms:**
- Time Machine uses FQDN (`motoko.pangolin-vega.ts.net`) but regular mounts use short name (`motoko`)
- Inconsistent behavior between Time Machine and regular mounts

**Note:**
This is expected behavior:
- Time Machine uses FQDN for reliability across network changes
- Regular mounts use short hostname for simplicity
- Both should work if MagicDNS is configured correctly

**Fix:**
```bash
# Verify MagicDNS is working
ping motoko.pangolin-vega.ts.net
ping motoko

# Check /etc/resolver configuration
cat /etc/resolver/pangolin-vega.ts.net

# If missing, recreate:
TAILNET=$(tailscale status --json | jq -r '.MagicDNSSuffix')
sudo mkdir -p /etc/resolver
sudo bash -c "echo 'nameserver 100.100.100.100' > /etc/resolver/$TAILNET"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## Server-Side Checks

If client-side fixes don't work, check the server:

```bash
# On motoko, verify SMB service is running
systemctl status smb  # Note: Fedora uses 'smb' not 'smbd'

# Check SMB logs for errors
sudo tail -50 /var/log/samba/log.smbd

# Verify SMB share is accessible
smbclient -L localhost -U mdt

# Check /time directory exists and has correct permissions
ls -ld /time
```

### 6. USB Drive Device Name Drift (CRITICAL - Server-Side)

**Symptoms:**
- `ls /time` shows "Input/output error" on motoko
- `mount | grep /time` shows multiple mounts or `emergency_ro` flag
- `dmesg | grep -i error` shows EXT4 read errors on sdb/sdc (but disk is now sdd)
- Time Machine shows "Failed to mount destination" error (Error Code 26)
- `df -h` shows `/time` or `/space` mounted but kernel reports I/O errors

**Root Cause:**
USB drives can change device names (e.g., `/dev/sdb` → `/dev/sdd`) after:
- Server reboots
- USB cable disconnections
- Power cycling the drive
- USB hub issues

When this happens:
1. The kernel keeps stale mounts to the old device names
2. These stale mounts overlay the correct mountpoint
3. Any access to `/time` or `/space` returns I/O errors
4. The filesystem may be marked `emergency_ro` due to accumulated errors

**Diagnosis:**
```bash
# SSH to motoko
tailscale ssh mdt@motoko

# Check for multiple/stale mounts
mount | grep -E "/time|/space"
# BAD: Multiple entries or emergency_ro flag
# GOOD: Single entry per mountpoint

# Check current disk layout
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID | grep -E "sd|time|space"

# Check kernel errors
sudo dmesg | grep -i "error" | tail -30

# Verify fstab uses UUIDs (not device names)
cat /etc/fstab | grep -E "/time|/space"
# GOOD: UUID=xxxx /time ext4 ...
# BAD:  /dev/sdb1 /time ext4 ...
```

**Fix (Automated - Recommended):**
```bash
# Run the recovery script on motoko
tailscale ssh mdt@motoko 'sudo /path/to/miket-infra-devices/scripts/fix-motoko-storage-mounts.sh'
```

**Fix (Manual):**
```bash
# 1. Stop Samba to release mount handles
sudo systemctl stop smb

# 2. Force unmount all stale mounts (repeat until none left)
sudo umount -l /time
sudo umount -l /time
sudo umount -l /space

# 3. Verify mounts are cleared
mount | grep -E "/time|/space"  # Should be empty

# 4. Remount from fstab (uses stable UUIDs)
sudo mount -a

# 5. Verify mounts are accessible
ls /time /space  # Should show contents

# 6. Restart Samba
sudo systemctl start smb

# 7. Verify Samba connections
sudo smbstatus
```

**Prevention:**
1. **Use UUIDs in fstab:** Always configure mounts via UUID, never device names
2. **Health monitoring:** Run `check-motoko-storage-health.sh` periodically
3. **Stable USB connection:** Use direct USB ports, avoid hubs if possible
4. **systemd mount units:** Consider using systemd .mount units instead of fstab for better dependency handling

**Related Scripts:**
- `scripts/check-motoko-storage-health.sh` - Health check for storage mounts
- `scripts/fix-motoko-storage-mounts.sh` - Recovery script for mount issues

## Improved Mount Script

The mount script (`~/.scripts/mount_shares.sh`) has been updated to:

1. **Detect stale mounts:** Tests if mounts are actually accessible using `ls` before assuming they're working
2. **Auto-remount:** Automatically unmounts and remounts stale mounts
3. **Better logging:** Logs when mounts are stale vs. when they're working

This prevents the "Socket is not connected" errors that were causing Time Machine failures.

## Verification Steps

After applying fixes, verify:

1. **Regular mounts are working:**
   ```bash
   ls ~/.mkt/space ~/.mkt/flux ~/.mkt/time
   # Should show directory contents, not errors
   ```

2. **Time Machine mount exists:**
   ```bash
   mount | grep -i timemachine
   # Should show Time Machine mount
   ```

3. **Time Machine can access backup volume:**
   ```bash
   tmutil status
   # Should show backup progressing or completed, not stuck in FindingBackupVol
   ```

4. **Time Machine backup succeeds:**
   - Check System Settings > Time Machine
   - Look for successful backup timestamps
   - Check backup size matches expectations

## Related Files

### Client-side (count-zero)
- Mount script: `~/.scripts/mount_shares.sh`
- Mount log: `~/.scripts/mount_shares.log`
- Secrets file: `~/.mkt/mounts.env`

### Server-side (motoko)
- Samba config: `/etc/samba/smb.conf`
- Mount config: `/etc/fstab` (uses UUIDs)
- Storage paths: `/time`, `/space`, `/flux`

### Diagnostic/Recovery Scripts
- `scripts/diagnose-timemachine-smb.sh` - Client-side diagnostics
- `scripts/check-motoko-storage-health.sh` - Server-side health check
- `scripts/fix-motoko-storage-mounts.sh` - Server-side mount recovery
- `scripts/troubleshoot-count-zero-space.sh` - General troubleshooting

## Prevention

To prevent future issues:

1. **Keep mounts healthy:** 
   - Client: The mount script automatically detects and fixes stale mounts
   - Server: Run `check-motoko-storage-health.sh` periodically (or via cron/systemd timer)
2. **Monitor Time Machine:** Check System Settings > Time Machine regularly for failed backups
3. **Network stability:** Ensure Tailscale is running and MagicDNS is configured correctly
4. **Server health:** 
   - Monitor motoko SMB service and disk space
   - Use UUIDs in fstab (never device names like /dev/sdb1)
   - Watch for kernel I/O errors: `sudo dmesg | grep -i error`
5. **USB stability:** Use direct USB ports on motoko, avoid USB hubs for the storage drive

