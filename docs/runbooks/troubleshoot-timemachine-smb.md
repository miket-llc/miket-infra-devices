---
document_title: "Troubleshoot Time Machine SMB Connection Issues"
author: "Codex-CA-001"
last_updated: 2025-12-04
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-12-04-timemachine-smb-troubleshooting
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
systemctl status smbd

# Check SMB logs for errors
tail -50 /var/log/samba/log.smbd

# Verify SMB share is accessible
smbclient -L localhost -U mdt

# Check /time directory exists and has correct permissions
ls -ld /time
```

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

- Mount script: `~/.scripts/mount_shares.sh`
- Mount log: `~/.scripts/mount_shares.log`
- Secrets file: `~/.mkt/mounts.env`
- Diagnostic script: `scripts/diagnose-timemachine-smb.sh`
- Troubleshooting script: `scripts/troubleshoot-count-zero-space.sh`

## Prevention

To prevent future issues:

1. **Keep mounts healthy:** The updated mount script automatically detects and fixes stale mounts
2. **Monitor Time Machine:** Check System Settings > Time Machine regularly for failed backups
3. **Network stability:** Ensure Tailscale is running and MagicDNS is configured correctly
4. **Server health:** Monitor motoko SMB service and disk space

