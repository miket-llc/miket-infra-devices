# Autofs Linux Mounts Role

On-demand CIFS mounting via autofs for Linux workstations.

## Why Autofs Instead of Static Mounts?

On **2024-12-01**, atom (resilience node) experienced a desktop freeze caused by a CIFS kernel bug (`cfids_invalidation_worker`). When the network to motoko hiccupped, the kernel module tried to invalidate directory caches and hit a "scheduling while atomic" bug, which cascaded to dbus failures and froze GNOME.

**Static fstab mounts are dangerous** on Linux desktops because:
- The CIFS kernel module runs in kernel space
- Bugs in it can take down the entire system
- Network hiccups are inevitable

**Autofs solves this** by:
- Mounting only when you access the directory
- Unmounting automatically after idle timeout
- Using `soft` mount options so operations timeout instead of hanging
- Isolating mount issues from the rest of the system

## Usage

### For Linux Workstations (NOT resilience nodes)

```yaml
# In your playbook
- hosts: linux_workstations
  roles:
    - role: mount_shares_linux_autofs
      vars:
        smb_password: "{{ lookup('pipe', 'az keyvault secret show ...') }}"
```

### Host Variables

```yaml
# host_vars/myworkstation.yml
smb_server: motoko.pangolin-vega.ts.net
smb_username: mdt
smb_password: "{{ lookup(...) }}"

# Optional: customize timeout
autofs_timeout: 600  # 10 minutes

# Optional: customize mount base
autofs_mount_base: /mnt/shares
```

## What Gets Configured

| Item | Path | Purpose |
|------|------|---------|
| Autofs master | `/etc/auto.master` | Registers the motoko map |
| Autofs map | `/etc/auto.motoko` | Defines share mount points |
| Credentials | `/root/.smbcredentials_motoko` | SMB auth (mode 0600) |
| Mount base | `/mnt/motoko/` | Parent directory for mounts |
| Symlinks | `~/flux`, `~/space`, `~/time` | User-friendly access |

## Accessing Shares

After deployment, shares mount automatically when accessed:

```bash
# This triggers the mount
ls ~/flux

# Check what's mounted
mount | grep autofs
mount | grep cifs

# Force unmount (autofs will remount on next access)
sudo umount /mnt/motoko/flux
```

## When NOT to Use This Role

| Device Type | Use Instead | Why |
|-------------|-------------|-----|
| Resilience nodes (atom) | No mounts at all | Zero dependencies on other servers |
| Servers (motoko) | Bind mounts | It's the source of the shares |
| Windows | `mount_shares_windows` | Different SMB client |
| macOS | `mount_shares_macos` | Uses mount_smbfs |

## Troubleshooting

### Share won't mount

```bash
# Check autofs status
systemctl status autofs

# Check autofs logs
journalctl -u autofs -f

# Manual mount test
sudo mount -t cifs //motoko.pangolin-vega.ts.net/flux /mnt/test -o credentials=/root/.smbcredentials_motoko
```

### Share is stuck

```bash
# Force unmount
sudo umount -l /mnt/motoko/flux

# Restart autofs
sudo systemctl restart autofs
```

### Network hiccup caused issues

With autofs + soft mounts, operations should timeout gracefully. If you're still seeing hangs, check that the `soft,timeo=30` options are in `/etc/auto.motoko`.

