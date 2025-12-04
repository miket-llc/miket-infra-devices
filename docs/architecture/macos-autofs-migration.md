---
document_title: "macOS Autofs Migration Guide"
author: "Codex-CA-001"
last_updated: 2025-12-04
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-12-04-autofs-macos-migration
---

# macOS Autofs Migration Guide

## Overview

This document describes the migration from manual SMB mounts (`mount_shares_macos`) to autofs-based mounts (`mount_shares_macos_autofs`) for improved reliability.

## Why Migrate?

### Current Issues with Manual Mounts

1. **Stale Mounts**: After network interruptions or sleep/wake cycles, mounts become stale ("Socket is not connected")
2. **Time Machine Failures**: Stale mounts break Time Machine backups
3. **Periodic Checking**: Requires a script that runs every 5 minutes to check mounts
4. **Manual Recovery**: Requires manual intervention when mounts fail

### Benefits of Autofs

1. **On-Demand Mounting**: Shares mount automatically when accessed
2. **Automatic Unmounting**: Unmounts after idle timeout (5 minutes default)
3. **No Stale Mounts**: Autofs handles disconnections gracefully
4. **No Periodic Scripts**: macOS automountd handles everything
5. **Better Reliability**: Improved reliability for Time Machine and other services

## Migration Steps

### 1. Update Playbook

Change from:
```yaml
- hosts: count-zero
  roles:
    - role: mount_shares_macos
```

To:
```yaml
- hosts: count-zero
  roles:
    - role: mount_shares_macos_autofs
```

### 2. Run Ansible Playbook

```bash
ansible-playbook -i inventory/hosts.yml playbooks/mount-shares-count-zero.yml
```

The role will automatically:
- Unmount old manual mounts
- Remove old LaunchAgent
- Remove old mount script
- Configure autofs

### 3. Verify Migration

```bash
# Check autofs configuration
cat /etc/auto_master | grep motoko
cat /etc/auto.motoko

# Test mounts (they should mount on-demand)
ls ~/space ~/flux ~/time

# Check mount status
mount | grep autofs
mount | grep smbfs
```

### 4. Test Time Machine

```bash
# Check Time Machine status
tmutil status

# If needed, restart Time Machine
tmutil stopbackup
tmutil startbackup --auto
```

## Configuration Details

### Autofs Master File

`/etc/auto_master` entry:
```
/Volumes/motoko /etc/auto.motoko --timeout=300
```

**Note:** Uses `/Volumes/motoko` instead of `/mnt/motoko` because macOS SIP (System Integrity Protection) makes `/mnt` read-only.

### Autofs Map File

`/etc/auto.motoko` contains (password URL-encoded, file mode 0600):
```
flux -fstype=smbfs,soft,noowners,nosuid,rw ://mdt:URL_ENCODED_PASSWORD@motoko/flux
space -fstype=smbfs,soft,noowners,nosuid,rw ://mdt:URL_ENCODED_PASSWORD@motoko/space
```

**NOTE:** The `time` share is **excluded from autofs** because Time Machine manages it directly. Time Machine mounts to `/Volumes/.timemachine/...` and should not go through autofs.

**Secrets Architecture Compliance:**
- Password source: Azure Key Vault secret `motoko-smb-password`
- Synced to `~/.mkt/mounts.env` via `ansible/playbooks/secrets-sync.yml`
- Role reads from env file (ephemeral cache pattern)
- macOS autofs limitation: Password must be embedded in URL (no credentials file support)
- File permissions: 0600 (root:wheel) to restrict access

### Mount Points

- System mount base: `/Volumes/motoko/` (macOS SIP-compliant)
- User symlinks: `~/flux`, `~/space` (time excluded - Time Machine manages it)
- Time Machine mount: `/Volumes/.timemachine/motoko.pangolin-vega.ts.net/.../time` (managed by Time Machine directly)

## Troubleshooting

### Shares Not Mounting

```bash
# Reload autofs configuration
sudo automount -vc

# Check automountd status
launchctl list | grep automountd

# Check autofs logs
log show --predicate 'process == "automountd"' --last 1h
```

### Credentials Issues

The password is URL-encoded and stored in `/etc/auto.motoko`. If credentials change:

1. Update `~/.mkt/mounts.env` with new password
2. Re-run the Ansible playbook
3. Reload autofs: `sudo automount -vc`

### Time Machine Configuration

**IMPORTANT:** The `time` share is **excluded from autofs** because Time Machine manages it directly. Time Machine mounts to `/Volumes/.timemachine/...` and should not go through autofs.

- Autofs only manages: `flux` and `space` shares
- Time Machine manages: `time` share directly via its own mount mechanism
- No `~/time` symlink is created (Time Machine uses its own mount path)

### Time Machine Still Failing

If Time Machine fails:

1. Ensure autofs mounts are working: `ls ~/space ~/flux`
2. Check Time Machine mount: `mount | grep timemachine`
3. Restart Time Machine: `tmutil stopbackup && tmutil startbackup --auto`
4. Check Time Machine status: `tmutil status`
5. If needed, remove and re-add Time Machine destination: `tmutil removedestination <ID>`

## Rollback

If you need to rollback to manual mounts:

1. Update playbook to use `mount_shares_macos` role
2. Remove autofs configuration:
   ```bash
   sudo sed -i '' '/\/Volumes\/motoko/d' /etc/auto_master
   sudo rm /etc/auto.motoko
   sudo automount -vc
   ```
3. Re-run Ansible playbook

## Related Documentation

- [Linux Autofs Strategy](../architecture/linux-mount-strategy.md)
- [Troubleshoot Time Machine SMB](../runbooks/troubleshoot-timemachine-smb.md)
- [Mount Shares macOS Autofs Role](../../ansible/roles/mount_shares_macos_autofs/README.md)

