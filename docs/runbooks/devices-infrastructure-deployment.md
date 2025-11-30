# Devices Infrastructure Deployment Runbook

**Purpose:** Deploy and validate the complete devices infrastructure including mounts, OS cloud sync, and devices view  
**Owner:** Chief Device Architect (Codex-DCA-001)  
**Last Updated:** 2025-11-20

## Overview

This runbook covers the deployment of the devices infrastructure across macOS, Windows, and the motoko server. The implementation provides:

- System-level SMB mounts on macOS (`/mkt/*`)
- Network drive mappings on Windows (`X:`, `S:`, `T:`)
- User-friendly symlinks on all platforms
- Automated OS cloud synchronization (iCloud/OneDrive → `/space/devices`)
- Unified devices view accessible across all platforms
- Comprehensive loop prevention

## Architecture

### Mount Points

**macOS:**
- `/mkt/flux` → `//motoko/flux` (SMB)
- `/mkt/space` → `//motoko/space` (SMB)
- `/mkt/time` → `//motoko/time` (SMB)
- User symlinks: `~/flux`, `~/space`, `~/time` → `/mkt/*`

**Windows:**
- `X:` → `\\motoko\flux` (labeled FLUX)
- `S:` → `\\motoko\space` (labeled SPACE)
- `T:` → `\\motoko\time` (labeled TIME)

### OS Cloud Sync

**Sources (macOS):**
- `~/Library/Mobile Documents/com~apple~CloudDocs` → `/space/devices/<host>/<user>/icloud/`
- `~/OneDrive` → `/space/devices/<host>/<user>/onedrive-personal/`
- `~/Library/CloudStorage/OneDrive-*` → `/space/devices/<host>/<user>/onedrive-business/`

**Sources (Windows):**
- `%USERPROFILE%\OneDrive` → `/space/devices/<host>/<user>/onedrive-personal/`
- `%USERPROFILE%\OneDrive - *` → `/space/devices/<host>/<user>/onedrive-business/`
- `%USERPROFILE%\iCloudDrive` → `/space/devices/<host>/<user>/icloud/` (if installed)

**Schedule:** Daily at 2:30 AM (configurable)

### Devices View

- Server: `/space/devices/<hostname>/<username>/`
- User path: `/space/mike/devices` → `/space/devices` (symlink)
- macOS access: `~/space/mike/devices`
- Windows access: `S:\mike\devices`

## Prerequisites

1. **Server (motoko):**
   - SMB shares configured: `/flux`, `/space`, `/time`
   - Sufficient storage space in `/space/devices`
   - User accounts configured with SMB passwords

2. **Clients (all):**
   - Tailscale connectivity to motoko
   - Ansible connectivity established
   - Azure CLI installed (macOS only, for Key Vault access)
   - User credentials stored in Azure Key Vault

3. **Ansible Control Node:**
   - Inventory up to date (`ansible/inventory/hosts.yml`)
   - Vault passwords configured if using encrypted vars

## Deployment Steps

### Phase 1: Server Setup (motoko)

```bash
# From Ansible control node
cd /path/to/miket-infra-devices/ansible

# Deploy devices structure on motoko
ansible-playbook -i inventory/hosts.yml playbooks/motoko/setup-devices-structure.yml

# Verify structure created
ansible motoko -i inventory/hosts.yml -m shell -a "ls -la /space/devices/"
ansible motoko -i inventory/hosts.yml -m shell -a "ls -la /space/mike/"
```

**Expected Output:**
- `/space/devices/` directory exists
- `/space/mike/devices` symlink points to `/space/devices`
- README.txt created in `/space/devices/`

### Phase 2: macOS Client Deployment

```bash
# Deploy mount configuration and OS cloud sync to macOS clients
ansible-playbook -i inventory/hosts.yml playbooks/deploy-mounts-macos.yml

# Or deploy just mounts or just sync
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags macos,mounts
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags macos,oscloud
```

**Post-Deployment Actions (Per User):**
1. Log out and log back in
2. Verify mounts: `ls -la /mkt/`
3. Verify symlinks: `ls -la ~/ | grep -E 'flux|space|time'`
4. Run loop check: `~/.scripts/check_oscloud_loops.sh`
5. Test manual sync: `~/.scripts/oscloud-sync/sync_to_devices.sh`

### Phase 3: Windows Client Deployment

```bash
# Deploy mount configuration and OS cloud sync to Windows clients
ansible-playbook -i inventory/hosts.yml playbooks/deploy-mounts-windows.yml

# Or deploy just mounts or just sync
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags windows,mounts
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml --tags windows,oscloud
```

**Post-Deployment Actions (Per User):**
1. Log off and log back on
2. Verify drives in File Explorer: X:, S:, T:
3. Check drive labels (right-click properties)
4. Run loop check: `C:\Scripts\Check-OneDriveLoops.ps1`
5. Test manual sync: `C:\Scripts\oscloud-sync\Sync-ToDevices.ps1`

### Phase 4: Complete Deployment (All at Once)

```bash
# Deploy everything in order
ansible-playbook -i inventory/hosts.yml playbooks/deploy-devices-infrastructure.yml

# This runs all phases automatically:
# 1. Setup devices structure on motoko
# 2. Deploy macOS mount configuration
# 3. Deploy Windows mount configuration
# 4. Deploy OS cloud sync to all clients
```

## Validation

### Automated Validation

```bash
# Run comprehensive validation checks
ansible-playbook -i inventory/hosts.yml playbooks/validate-devices-infrastructure.yml
```

### Manual Validation Checklist

**Server (motoko):**
- [ ] `/space/devices/` exists and is writable
- [ ] `/space/mike/devices` symlink correct
- [ ] Device subdirectories created: `count-zero/`, `wintermute/`, `armitage/`

**macOS (count-zero):**
- [ ] `~/.mkt` directory exists: `ls -la ~/.mkt`
- [ ] SMB mounts active: `mount | grep ~/.mkt`
- [ ] User symlinks correct: `ls -la ~/ | grep -E 'flux|space|time'`
- [ ] `~/flux` → `~/.mkt/flux`
- [ ] `~/space` → `~/.mkt/space`
- [ ] `~/time` → `~/.mkt/time`
- [ ] Sync script exists: `~/.scripts/oscloud-sync/sync_to_devices.sh`
- [ ] LaunchAgents loaded: `launchctl list | grep com.miket`
- [ ] Loop check passes: `~/.scripts/check_oscloud_loops.sh`

**Windows (wintermute, armitage):**
- [ ] X: drive mounted and labeled FLUX
- [ ] S: drive mounted and labeled SPACE
- [ ] T: drive mounted and labeled TIME
- [ ] Drives pinned in Quick Access
- [ ] Sync script exists: `C:\Scripts\oscloud-sync\Sync-ToDevices.ps1`
- [ ] Scheduled task configured: `Get-ScheduledTask -TaskName "MikeT OS Cloud Sync"`
- [ ] Loop check passes: `C:\Scripts\Check-OneDriveLoops.ps1`

**Devices View (all platforms):**
- [ ] macOS: `~/space/mike/devices` accessible
- [ ] Windows: `S:\mike\devices` accessible
- [ ] Can see device subdirectories from all clients

### First Sync Validation

Wait 24 hours after deployment, then check:

```bash
# On motoko, verify sync ran
ls -la /space/devices/count-zero/miket/
ls -la /space/devices/wintermute/mdt/
ls -la /space/devices/armitage/mdt/

# Check sync logs on clients
# macOS:
tail -n 50 ~/.scripts/oscloud-sync/sync.log

# Windows:
Get-Content C:\Scripts\oscloud-sync\sync.log -Tail 50
```

## Troubleshooting

### macOS: Mounts Not Appearing

**Symptoms:** `~/.mkt/*` directories empty or not mounted

**Diagnosis:**
```bash
mount | grep ~/.mkt
launchctl list | grep com.miket.storage-connect
cat ~/.scripts/mount_shares.err
```

**Common Causes:**
1. Network not available when LaunchAgent ran
2. Azure Key Vault credentials not accessible
3. SMB password incorrect
4. motoko not reachable

**Resolution:**
```bash
# Manual mount test
~/.scripts/mount_shares.sh

# Check Azure login
az account show

# Re-login if needed
az login

# Reload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist
launchctl load ~/Library/LaunchAgents/com.miket.storage-connect.plist
```

### macOS: Symlinks Not Created

**Symptoms:** `~/flux`, `~/space`, `~/time` don't exist

**Diagnosis:**
```bash
ls -la ~/ | grep -E 'flux|space|time'
cat /tmp/com.miket.usersymlinks.err
```

**Resolution:**
```bash
# Symlinks are created automatically by mount script
# Re-run mount script to recreate symlinks
~/.scripts/mount_shares.sh

# Or reload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist
launchctl load ~/Library/LaunchAgents/com.miket.storage-connect.plist
```

### Windows: Drives Not Mapped

**Symptoms:** X:, S:, T: not visible in File Explorer

**Diagnosis:**
```powershell
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -in @('X','S','T')}
net use
```

**Common Causes:**
1. Network not available when user logged on
2. Credentials not saved
3. motoko not reachable

**Resolution:**
```powershell
# Manual mapping
net use X: \\motoko.pangolin-vega.ts.net\flux /persistent:yes
net use S: \\motoko.pangolin-vega.ts.net\space /persistent:yes
net use T: \\motoko.pangolin-vega.ts.net\time /persistent:yes

# Or re-run Ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-mounts-windows.yml -l <hostname>
```

### OS Cloud Sync Not Running

**Symptoms:** No files in `/space/devices/<hostname>/<user>/`

**macOS Diagnosis:**
```bash
# Check LaunchAgent status
launchctl list | grep com.miket.oscloud.sync

# Check next run time
launchctl print user/$(id -u)/com.miket.oscloud.sync

# Check logs
cat ~/.scripts/oscloud-sync/sync.log
cat /tmp/com.miket.oscloud.sync.err
```

**Windows Diagnosis:**
```powershell
# Check scheduled task
Get-ScheduledTask -TaskName "MikeT OS Cloud Sync"
Get-ScheduledTaskInfo -TaskName "MikeT OS Cloud Sync"

# Check logs
Get-Content C:\Scripts\oscloud-sync\sync.log -Tail 50
```

**Resolution:**
```bash
# macOS: Manual sync test
~/.scripts/oscloud-sync/sync_to_devices.sh

# Windows: Manual sync test
C:\Scripts\oscloud-sync\Sync-ToDevices.ps1
```

### iCloud/OneDrive Sync Loops Detected

**Symptoms:** Warning from loop check scripts

**Resolution:**

**macOS:**
1. Open System Settings → Apple ID → iCloud → iCloud Drive → Options
2. Ensure Desktop and Documents folders do NOT sync
3. Verify `/mkt`, `~/flux`, `~/space`, `~/time` are not inside iCloud Drive
4. Check OneDrive settings to exclude symlinks from sync

**Windows:**
1. Right-click OneDrive icon in system tray → Settings
2. Go to Backup tab
3. Verify X:, S:, T: are NOT selected for backup
4. Go to Account tab → Choose folders
5. Verify no network drive paths are selected

## Rollback Procedure

If deployment fails or causes issues:

### macOS Rollback

```bash
# Stop LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.miket.mountshares.plist
launchctl unload ~/Library/LaunchAgents/com.miket.usersymlinks.plist
launchctl unload ~/Library/LaunchAgents/com.miket.oscloud.sync.plist

# Unmount shares
umount /mkt/flux
umount /mkt/space
umount /mkt/time

# Remove symlinks
rm ~/flux ~/space ~/time

# Restore old configuration if needed
# (revert to ~/Mounts/* if that was previous setup)
```

### Windows Rollback

```powershell
# Unmap drives
net use X: /delete
net use S: /delete
net use T: /delete

# Disable scheduled task
Disable-ScheduledTask -TaskName "MikeT OS Cloud Sync"

# Restore previous drive mappings if needed
# (e.g., F: for flux)
```

## Post-Deployment Monitoring

### Week 1 Checks

- Day 1: Verify initial sync completed on all clients
- Day 2: Check sync logs for errors
- Day 3: Spot-check devices view from different clients
- Day 7: Verify storage usage growth is reasonable

### Ongoing Monitoring

- Monthly: Review sync logs for patterns or errors
- Monthly: Verify `/space/devices` storage usage
- Quarterly: Test manual sync on all clients
- Quarterly: Re-run validation playbook

## Related Documentation

- [DATA_LIFECYCLE_SPEC.md](../product/DATA_LIFECYCLE_SPEC.md) - Overall data lifecycle design
- [ARCHITECTURE_HANDOFF_FLUX.md](../product/ARCHITECTURE_HANDOFF_FLUX.md) - Flux/Time/Space architecture
- [COMMUNICATION_LOG.md](../communications/COMMUNICATION_LOG.md#2025-11-20-devices-infra) - Implementation log

## Change History

| Date | Change | Author |
|------|--------|--------|
| 2025-11-20 | Initial creation | Codex-DCA-001 |

