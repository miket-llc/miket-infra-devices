# Autofs macOS Mounts Role

On-demand SMB mounting via autofs for macOS workstations.

## Why Autofs Instead of Manual Mounts?

The current `mount_shares_macos` role uses manual `mount_smbfs` commands with a launchd script that runs periodically. This approach has several problems:

1. **Stale mounts**: After network interruptions or sleep/wake cycles, mounts become stale ("Socket is not connected")
2. **Time Machine failures**: Stale mounts break Time Machine backups
3. **Periodic checking**: Requires a script that runs every 5 minutes to check mounts
4. **No automatic recovery**: Manual intervention needed when mounts fail

**Autofs solves this** by:
- Mounting only when you access the directory (on-demand)
- Unmounting automatically after idle timeout (5 minutes default)
- No stale mounts - autofs handles disconnections gracefully
- No periodic scripts needed - macOS automountd handles everything
- Better reliability for Time Machine and other services

## Usage

### For macOS Workstations

```yaml
# In your playbook
- hosts: macos_workstations
  roles:
    - role: mount_shares_macos_autofs
```

### Host Variables

```yaml
# host_vars/count-zero.yml
smb_server: motoko
smb_username: mdt
smb_env_file: "{{ ansible_env.HOME }}/.mkt/mounts.env"

# Optional: customize timeout
autofs_timeout: 600  # 10 minutes

# Optional: customize mount base (default: /Volumes/motoko for macOS SIP compliance)
autofs_mount_base: /Volumes/motoko
```

## What Gets Configured

| Item | Path | Purpose |
|------|------|---------|
| Autofs master | `/etc/auto_master` | Registers the motoko map |
| Autofs map | `/etc/auto.motoko` | Defines share mount points (mode 0600, contains URL-encoded password) |
| Secrets cache | `~/.mkt/mounts.env` | Ephemeral cache from AKV (synced via secrets-sync.yml) |
| Mount base | `/Volumes/motoko/` | Parent directory for mounts (macOS SIP-compliant) |
| Symlinks | `~/flux`, `~/space` | User-friendly access (time excluded - Time Machine manages it) |

**Secrets Architecture Compliance:**
- Source: Azure Key Vault secret `motoko-smb-password`
- Pattern: AKV → `~/.mkt/mounts.env` (ephemeral cache) → role consumption
- macOS Limitation: autofs requires password in URL (no credentials file support like Linux)
- File Permissions: `/etc/auto.motoko` restricted to 0600 (root:wheel)

## Accessing Shares

After deployment, shares mount automatically when accessed:

```bash
# This triggers the mount
ls ~/flux

# Check what's mounted
mount | grep autofs
mount | grep smbfs

# Force unmount (autofs will remount on next access)
umount /Volumes/motoko/flux
```

## Migration from Manual Mounts

When migrating from `mount_shares_macos` to `mount_shares_macos_autofs`:

1. The role automatically unmounts old manual mounts
2. Removes the old LaunchAgent (`com.miket.storage-connect.plist`)
3. Removes the old mount script (`~/.scripts/mount_shares.sh`)
4. Sets up autofs configuration

## Troubleshooting

### Shares Not Mounting

```bash
# Check autofs configuration
cat /etc/auto_master | grep motoko
cat /etc/auto.motoko

# Check automountd status
launchctl list | grep automountd

# Reload autofs configuration
sudo automount -vc

# Check autofs logs
log show --predicate 'process == "automountd"' --last 1h
```

### Credentials Issues

The password is URL-encoded and stored in `/etc/auto.motoko`. Source is Azure Key Vault secret `motoko-smb-password` synced to `~/.mkt/mounts.env`.

```bash
# Verify secrets cache exists
ls -la ~/.mkt/mounts.env

# If missing, sync from AKV
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit count-zero

# Test SMB connection manually
mount_smbfs //mdt@motoko/space /tmp/test_mount
umount /tmp/test_mount
```

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

## Comparison with Linux Autofs

| Feature | Linux (`mount_shares_linux_autofs`) | macOS (`mount_shares_macos_autofs`) |
|---------|-----------------------------------|-------------------------------------|
| Master file | `/etc/auto.master` | `/etc/auto_master` |
| Map file | `/etc/auto.motoko` | `/etc/auto.motoko` |
| Mount type | `cifs` | `smbfs` |
| Service | `systemd` | `launchd` (automountd) |
| Credentials | `/root/.smbcredentials_motoko` (credentials file) | Password in URL (macOS limitation) |
| Mount base | `/mnt/motoko` | `/Volumes/motoko` (macOS SIP-compliant) |

## Related Roles

- `mount_shares_macos` - Old manual mount approach (deprecated)
- `mount_shares_linux_autofs` - Linux autofs implementation
- `mount_shares_windows` - Windows network drive mappings

