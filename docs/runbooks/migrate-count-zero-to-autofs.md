---
document_title: "Migrate count-zero to Autofs Mounts"
author: "Codex-CA-001"
last_updated: 2025-12-04
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-12-04-autofs-macos-migration
---

# Migrate count-zero to Autofs Mounts

**Goal:** Migrate count-zero from manual SMB mounts to autofs-based mounts for improved reliability.

## Prerequisites

1. **Ansible access to count-zero:**
   ```bash
   # From motoko, test connectivity
   ansible -i ansible/inventory/hosts.yml count-zero -m ping
   ```

2. **Sudo access on count-zero:**
   - The playbook requires `become: true` to modify `/etc/auto_master` and `/etc/auto.motoko`
   - Ensure the `miket` user has sudo privileges
   - If needed, add to sudoers: `sudo visudo` and add `miket ALL=(ALL) NOPASSWD: ALL`

3. **Secrets file exists:**
   ```bash
   # Verify secrets file exists on count-zero
   tailscale ssh count-zero 'test -f ~/.mkt/mounts.env && echo "OK" || echo "MISSING"'
   
   # If missing, sync secrets first
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/secrets-sync.yml --limit count-zero
   ```

## Migration Steps

### Step 1: Backup Current Configuration

```bash
# On count-zero, backup current mounts info
tailscale ssh count-zero 'mount | grep motoko > /tmp/mounts-backup.txt'
tailscale ssh count-zero 'cat /tmp/mounts-backup.txt'
```

### Step 2: Run the Migration Playbook

From motoko (or any machine with Ansible access):

```bash
cd /path/to/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/mount-shares-count-zero.yml
```

**What the playbook does:**
1. Unmounts old manual mounts (`~/.mkt/flux`, `~/.mkt/space`, `~/.mkt/time`)
2. Removes old LaunchAgent (`com.miket.storage-connect.plist`)
3. Removes old mount script (`~/.scripts/mount_shares.sh`)
4. Creates autofs configuration:
   - Adds entry to `/etc/auto_master`
   - Creates `/etc/auto.motoko` with share definitions
5. Creates user symlinks (`~/flux`, `~/space`, `~/time`)
6. Reloads autofs configuration

### Step 3: Verify Migration

On count-zero:

```bash
# Check autofs configuration
cat /etc/auto_master | grep motoko
cat /etc/auto.motoko

# Test mounts (they should mount on-demand)
ls ~/space ~/flux ~/time

# Check mount status
mount | grep autofs
mount | grep smbfs

# Verify symlinks
ls -la ~/space ~/flux ~/time
```

### Step 4: Test Time Machine

```bash
# Check Time Machine status
tmutil status

# If needed, restart Time Machine
tmutil stopbackup
tmutil startbackup --auto

# Monitor Time Machine
tmutil status
```

## Troubleshooting

### Playbook Fails: "sudo: a password is required"

**Solution:** Configure passwordless sudo for the `miket` user:

```bash
# On count-zero
sudo visudo

# Add this line:
miket ALL=(ALL) NOPASSWD: ALL
```

Or provide sudo password in inventory:
```yaml
# ansible/inventory/hosts.yml
count-zero:
  ansible_become_password: "{{ vault_count_zero_sudo_password }}"
```

### Shares Not Mounting

```bash
# Reload autofs configuration
sudo automount -vc

# Check automountd status
launchctl list | grep automountd

# Check autofs logs
log show --predicate 'process == "automountd"' --last 1h

# Test manual mount to verify credentials
mount_smbfs //mdt@motoko/space /tmp/test_mount
umount /tmp/test_mount
```

### Credentials Issues

The password is URL-encoded and stored in `/etc/auto.motoko`. If credentials change:

1. Update `~/.mkt/mounts.env` with new password
2. Re-run the playbook
3. Or manually update `/etc/auto.motoko` and reload: `sudo automount -vc`

### Time Machine Still Failing

1. Ensure autofs mounts are working: `ls ~/space ~/flux ~/time`
2. Restart Time Machine: `tmutil stopbackup && tmutil startbackup --auto`
3. Check Time Machine status: `tmutil status`
4. If needed, remove and re-add Time Machine destination:
   ```bash
   sudo tmutil removedestination <DESTINATION_ID>
   # Then add via System Settings > Time Machine
   ```

## Rollback

If you need to rollback to manual mounts:

1. Update playbook to use `mount_shares_macos` role:
   ```yaml
   roles:
     - mount_shares_macos
   ```

2. Remove autofs configuration:
   ```bash
   sudo sed -i '' '/\/mnt\/motoko/d' /etc/auto_master
   sudo rm /etc/auto.motoko
   sudo automount -vc
   ```

3. Re-run the playbook

## Expected Behavior After Migration

### Before (Manual Mounts)
- Mounts created at login via LaunchAgent
- Script runs every 5 minutes to check mounts
- Stale mounts can occur after network interruptions
- Time Machine fails when mounts are stale

### After (Autofs)
- Mounts created on-demand when accessed
- Automatically unmount after 5 minutes idle
- No stale mounts - autofs handles disconnections
- Time Machine works reliably
- No periodic scripts needed

## Verification Checklist

- [ ] Autofs configuration files created (`/etc/auto_master`, `/etc/auto.motoko`)
- [ ] Old manual mounts unmounted
- [ ] Old LaunchAgent removed
- [ ] Old mount script removed
- [ ] User symlinks created (`~/flux`, `~/space`, `~/time`)
- [ ] Shares mount on-demand when accessed
- [ ] Shares unmount after idle timeout
- [ ] Time Machine can access backup volume
- [ ] No stale mount errors

## Related Documentation

- [macOS Autofs Migration Guide](../architecture/macos-autofs-migration.md)
- [Troubleshoot Time Machine SMB](./troubleshoot-timemachine-smb.md)
- [Mount Shares macOS Autofs Role](../../ansible/roles/mount_shares_macos_autofs/README.md)

