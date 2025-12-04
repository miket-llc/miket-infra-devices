# Nextcloud Permissions Troubleshooting

**Status:** ACTIVE  
**Target:** macOS workstations with Nextcloud client (count-zero)  
**Owner:** Infrastructure Team  

---

## Overview

This runbook covers troubleshooting and management of the Nextcloud Permissions Guard, a device-local safeguard that auto-corrects overly restrictive file/directory permissions in Nextcloud sync directories.

**Root Cause:** Obsidian and macOS sometimes create vault subdirectories with 700 permissions (`drwx------`), which blocks the Nextcloud client from reading/syncing them. This manifests as a red error icon on the affected folder in the Nextcloud client.

**Solution:** A periodic monitor (LaunchAgent) scans sync directories and normalizes permissions:
- Directories: `700` → `755`
- Files: `600` → `644`

> **IMPORTANT:** This guard operates on LOCAL sync directories only. It must NEVER touch `/space` (System of Record) on motoko.

---

## Symptoms

| Symptom | Description |
|---------|-------------|
| 🔴 Red icon on folder | Nextcloud client shows red error icon on a specific folder |
| "Cannot read directory" | Error message in Nextcloud client about unreadable directory |
| "Sync conflicts" | Files not syncing due to permission issues |
| Obsidian vault issues | Newly created Obsidian vault subfolders not syncing |

---

## Quick Diagnosis

### 1. Check for Restrictive Permissions

```bash
# On count-zero, check for 700 directories in sync root
find ~/cloud -type d -perm 700 2>/dev/null

# Check for 600 files
find ~/cloud -type f -perm 600 2>/dev/null

# Detailed view of a specific path
ls -ld ~/cloud/work/luci/pkm/ellucian-00
```

Expected output for healthy directories:
```
drwxr-xr-x  5 miket  staff  160 Dec  4 12:00 ellucian-00
```

Problematic output (triggers red icon):
```
drwx------  5 miket  staff  160 Dec  4 12:00 ellucian-00
```

### 2. Check Monitor Status

```bash
# Check if LaunchAgent is loaded
launchctl list | grep nextcloud-permissions

# Check LaunchAgent details
launchctl print gui/$(id -u)/com.miket.nextcloud-permissions-monitor

# View recent logs
tail -50 ~/Library/Logs/nextcloud-permissions-monitor.log
```

### 3. Run Monitor Manually

```bash
# Run the monitor to scan and fix permissions
/usr/local/miket/bin/monitor-nextcloud-permissions.sh ~/cloud

# Or run the fix script directly on a specific path
/usr/local/miket/bin/fix-nextcloud-folder-permissions.sh ~/cloud/work/luci/pkm
```

---

## How the Monitor Works

### Components

| Component | Path | Purpose |
|-----------|------|---------|
| Fix Script | `/usr/local/miket/bin/fix-nextcloud-folder-permissions.sh` | Normalizes permissions on given paths |
| Monitor Script | `/usr/local/miket/bin/monitor-nextcloud-permissions.sh` | Scans sync roots, delegates to fix script |
| LaunchAgent | `~/Library/LaunchAgents/com.miket.nextcloud-permissions-monitor.plist` | Runs monitor every 15 minutes |
| Log File | `~/Library/Logs/nextcloud-permissions-monitor.log` | Logs all scans and fixes |

### Execution Flow

1. **LaunchAgent** triggers `monitor-nextcloud-permissions.sh` every 15 minutes (and at login)
2. **Monitor** scans configured sync roots for:
   - Directories with `700` permissions (no group/other read/execute)
   - Files with `600` permissions (no group/other read)
3. **Fix Script** is called for each root with issues
4. Permissions are normalized to `755` (dirs) and `644` (files)
5. Results are logged to `~/Library/Logs/nextcloud-permissions-monitor.log`

### Configuration

The guard is configured via Ansible. Default settings:

| Setting | Default Value | Description |
|---------|---------------|-------------|
| `nextcloud_permissions_guard_enabled` | `true` | Enable/disable the guard |
| `nextcloud_permissions_guard_user` | `miket` | User running the monitor |
| `nextcloud_permissions_guard_sync_roots` | `["~/cloud"]` | Paths to monitor |
| `nextcloud_permissions_guard_interval` | `900` | Polling interval (seconds) |

---

## Temporarily Disable the Guard

### Option 1: Unload LaunchAgent (temporary)

```bash
# Unload the LaunchAgent (stops monitoring until next login or manual reload)
launchctl bootout gui/$(id -u)/com.miket.nextcloud-permissions-monitor

# To reload:
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.miket.nextcloud-permissions-monitor.plist
```

### Option 2: Disable via Ansible (persistent)

In `ansible/host_vars/count-zero.yml`, add:

```yaml
nextcloud_permissions_guard_enabled: false
```

Then re-run the playbook:

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nextcloud-permissions-guard.yml --limit count-zero
```

---

## Adjust Sync Roots

To change which directories are monitored:

### Option 1: Override in host_vars

In `ansible/host_vars/count-zero.yml`:

```yaml
nextcloud_permissions_guard_sync_roots:
  - "{{ ansible_env.HOME }}/cloud"
  - "{{ ansible_env.HOME }}/nc"
```

Then re-deploy:

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nextcloud-permissions-guard.yml --limit count-zero
```

### Option 2: Run manually with custom roots

```bash
# One-time scan of custom paths
/usr/local/miket/bin/monitor-nextcloud-permissions.sh "/Users/miket/cloud,/Users/miket/other-sync"
```

---

## Manual Fix for Immediate Relief

If you need to fix permissions immediately without waiting for the monitor:

```bash
# Fix a specific directory tree
/usr/local/miket/bin/fix-nextcloud-folder-permissions.sh ~/cloud/work/luci/pkm

# Fix with dry-run first (see what would change)
/usr/local/miket/bin/fix-nextcloud-folder-permissions.sh --dry-run ~/cloud

# Fix multiple paths
/usr/local/miket/bin/fix-nextcloud-folder-permissions.sh ~/cloud/work ~/cloud/inbox
```

---

## Testing the Guard

### Reproduce the Issue

```bash
# Create a directory with restrictive permissions
mkdir -m 700 ~/cloud/work/test-perms-issue

# Verify it's 700
ls -ld ~/cloud/work/test-perms-issue
# drwx------  2 miket  staff  64 Dec  4 12:00 test-perms-issue

# At this point, Nextcloud would show a red icon on this folder
```

### Verify Auto-Fix

```bash
# Option 1: Wait up to 15 minutes for automatic fix

# Option 2: Run monitor manually
/usr/local/miket/bin/monitor-nextcloud-permissions.sh ~/cloud

# Check that permissions were fixed
ls -ld ~/cloud/work/test-perms-issue
# drwxr-xr-x  2 miket  staff  64 Dec  4 12:00 test-perms-issue

# Clean up
rmdir ~/cloud/work/test-perms-issue
```

---

## Log File Analysis

### View Recent Activity

```bash
# Last 50 lines
tail -50 ~/Library/Logs/nextcloud-permissions-monitor.log

# Follow in real-time
tail -f ~/Library/Logs/nextcloud-permissions-monitor.log

# Search for fixes
grep "Fixed" ~/Library/Logs/nextcloud-permissions-monitor.log
```

### Sample Log Output

```
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Starting Nextcloud permissions monitor
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Fix script: /usr/local/miket/bin/fix-nextcloud-folder-permissions.sh
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Sync roots: /Users/miket/cloud
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Scanning: /Users/miket/cloud
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Found issues in /Users/miket/cloud: 1 dirs (700), 0 files (600)
2025-12-04 12:15:00 [nextcloud-perms-fix] INFO: Processing: /Users/miket/cloud (user: miket, dry_run: false)
2025-12-04 12:15:00 [nextcloud-perms-fix] INFO: Fixed dir permissions (755): /Users/miket/cloud/work/test-perms-issue
2025-12-04 12:15:00 [nextcloud-perms-fix] INFO: Summary for /Users/miket/cloud: dirs=1, files=0, chown=0
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Fixed in /Users/miket/cloud: 1 dirs, 0 files
2025-12-04 12:15:00 [nextcloud-perms-monitor] INFO: Monitor complete. Total fixes: 1
```

---

## Redeploy via Ansible

If the guard needs to be reinstalled or updated:

```bash
cd ~/miket-infra-devices/ansible

# Check what would change (dry-run)
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nextcloud-permissions-guard.yml --limit count-zero --check --diff

# Apply changes
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nextcloud-permissions-guard.yml --limit count-zero
```

---

## Troubleshooting

### LaunchAgent Not Running

```bash
# Check if plist exists
ls -la ~/Library/LaunchAgents/com.miket.nextcloud-permissions-monitor.plist

# Check if loaded
launchctl list | grep nextcloud-permissions

# If not loaded, manually load
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.miket.nextcloud-permissions-monitor.plist

# If still not working, check plist for errors
plutil -lint ~/Library/LaunchAgents/com.miket.nextcloud-permissions-monitor.plist
```

### Scripts Not Executable

```bash
# Check script permissions
ls -la /usr/local/miket/bin/fix-nextcloud-folder-permissions.sh
ls -la /usr/local/miket/bin/monitor-nextcloud-permissions.sh

# Should be -rwxr-xr-x (755)
# If not, fix via Ansible or manually:
sudo chmod 755 /usr/local/miket/bin/*.sh
```

### Permission Denied Errors

If the scripts fail with permission errors:

1. Verify the scripts are owned by the correct user:
   ```bash
   ls -la /usr/local/miket/bin/
   # Should be owned by miket
   ```

2. Verify the log directory is writable:
   ```bash
   ls -la ~/Library/Logs/
   touch ~/Library/Logs/test-write && rm ~/Library/Logs/test-write
   ```

3. Re-run Ansible to fix permissions:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-nextcloud-permissions-guard.yml --limit count-zero
   ```

---

## Related Documentation

- [Nextcloud Connection Troubleshooting](troubleshoot-count-zero-nextcloud.md)
- [Device Health Check Runbook](device-health-check.md)
- [Nextcloud Platform Contract](../reference/NEXTCLOUD_PLATFORM_CONTRACT.md)
- [IaC/CaC Principles](../reference/iac-cac-principles.md)

---

## Support

If issues persist after following this guide:

1. Collect diagnostic output:
   ```bash
   # On count-zero
   launchctl list | grep nextcloud > /tmp/nextcloud-perms-launchctl.txt
   cat ~/Library/Logs/nextcloud-permissions-monitor.log > /tmp/nextcloud-perms-log.txt
   find ~/cloud -type d -perm 700 > /tmp/nextcloud-perms-dirs.txt 2>&1
   ls -la /usr/local/miket/bin/ > /tmp/nextcloud-perms-scripts.txt
   ```

2. File issue with collected diagnostics

