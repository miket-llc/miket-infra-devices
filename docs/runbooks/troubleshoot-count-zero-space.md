# Troubleshoot count-zero Space Directory

**Issue:** Cannot see anything (or very little) in the space directory from count-zero.

## Quick Diagnosis

### Option 1: Run Diagnostic Playbook (Recommended)

From motoko:
```bash
cd /path/to/kvo
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/diagnose-mount-drift.yml --limit count-zero
```

This will generate a comprehensive drift report showing:
- Mount status for all three shares (flux, space, time)
- Whether paths are symlinks or shadow directories
- LaunchAgent status
- Secrets file status
- Network connectivity to motoko

### Option 2: Run Troubleshooting Script

Run the troubleshooting script on count-zero:
```bash
./scripts/troubleshoot-count-zero-space.sh
```

Or from motoko:
```bash
tailscale ssh count-zero 'bash -s' < scripts/troubleshoot-count-zero-space.sh
```

## Common Issues and Fixes

### 1. Space Not Mounted

**Symptoms:**
- `~/.mkt/space` exists but is empty
- `mount | grep space` shows nothing

**Fix:**
```bash
# On count-zero, run the mount script manually
~/.scripts/mount_shares.sh

# Check the log for errors
tail -20 ~/.scripts/mount_shares.log
```

### 2. SMB Credentials Missing

**Symptoms:**
- Error: "SMB_PASSWORD is not present"
- Secrets file missing or empty

**Fix:**
```bash
# From motoko, sync secrets to count-zero
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit count-zero

# Verify secrets file exists on count-zero
tailscale ssh count-zero 'test -f ~/.mkt/mounts.env && echo "OK" || echo "MISSING"'
```

### 3. LaunchAgent Not Running

**Symptoms:**
- Mounts don't appear on login
- `launchctl list | grep storage-connect` shows nothing

**Fix:**
```bash
# On count-zero, reload the LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.miket.storage-connect.plist

# Or re-run the Ansible playbook
ansible-playbook -i inventory/hosts.yml playbooks/mount-shares-count-zero.yml
```

### 4. Network Connectivity Issues

**Symptoms:**
- Cannot ping motoko
- SMB connection fails

**Fix:**
```bash
# On count-zero, check Tailscale
tailscale status

# Test connectivity
ping -c 3 motoko

# If Tailscale is down, restart it
tailscale up
```

### 5. Mount Appears Empty (Stale Mount)

**Symptoms:**
- Mount shows as mounted but directory is empty
- `ls ~/.mkt/space` shows nothing

**Fix:**
```bash
# On count-zero, unmount and remount
umount ~/.mkt/space
~/.scripts/mount_shares.sh

# Verify contents
ls -la ~/.mkt/space
```

### 6. Permissions Issue

**Symptoms:**
- Mount works but cannot read/write
- Permission denied errors

**Fix:**
```bash
# Verify SMB user on motoko
tailscale ssh motoko 'id mdt'

# Check SMB share permissions
tailscale ssh motoko 'ls -ld /space'

# Re-run mount with correct credentials
~/.scripts/mount_shares.sh
```

## Verification Steps

After applying fixes, verify:

1. **Mount Status:**
   ```bash
   mount | grep "on ${HOME}/.mkt/space"
   ```

2. **Directory Contents:**
   ```bash
   ls -la ~/.mkt/space
   # Should see: devices/, mike/, etc.
   ```

3. **Symlink:**
   ```bash
   ls -la ~/space
   # Should be a symlink to ~/.mkt/space
   ```

4. **Write Test:**
   ```bash
   touch ~/.mkt/space/.test-write
   rm ~/.mkt/space/.test-write
   ```

## Full Reset

If nothing works, do a full reset:

```bash
# On count-zero
# 1. Unmount everything
umount ~/.mkt/space 2>/dev/null
umount ~/.mkt/flux 2>/dev/null
umount ~/.mkt/time 2>/dev/null

# 2. Remove old LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist 2>/dev/null

# 3. From motoko, re-run Ansible
ansible-playbook -i inventory/hosts.yml playbooks/mount-shares-count-zero.yml

# 4. On count-zero, manually run mount script
~/.scripts/mount_shares.sh
```

## Server-Side Checks

If client-side fixes don't work, check the server:

```bash
# On motoko, verify SMB share is accessible
smbclient -L localhost -U mdt

# Check /space directory exists and has content
ls -la /space

# Check SMB service status
systemctl status smbd

# Check SMB logs
tail -50 /var/log/samba/log.smbd
```

## Related Files

- Mount script: `~/.scripts/mount_shares.sh`
- Mount log: `~/.scripts/mount_shares.log`
- Secrets file: `~/.mkt/mounts.env`
- LaunchAgent: `~/Library/LaunchAgents/com.miket.storage-connect.plist`
- Troubleshooting script: `scripts/troubleshoot-count-zero-space.sh`

