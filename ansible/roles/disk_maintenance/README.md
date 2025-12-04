# Disk Maintenance Role

Comprehensive disk cleanup role for motoko and other Linux hosts. Cleans Podman resources, journal logs, package cache, temporary files, and old log files.

## Purpose

This role performs comprehensive disk maintenance to free up disk space and inodes. It's designed to be run when disk space alerts are triggered or as part of regular maintenance.

## Usage

### Full Cleanup

```yaml
- hosts: motoko
  roles:
    - role: disk_maintenance
      vars:
        disk_maintenance_confirm: true
```

### Selective Cleanup

```yaml
- hosts: motoko
  roles:
    - role: disk_maintenance
      vars:
        disk_maintenance_confirm: true
        disk_maintenance_clean_podman: true
        disk_maintenance_clean_journal: true
        disk_maintenance_clean_tmp: false
        disk_maintenance_clean_package_cache: true
        disk_maintenance_clean_old_logs: true
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `disk_maintenance_confirm` | `false` | **Required:** Must be `true` to perform cleanup |
| `disk_maintenance_clean_podman` | `true` | Clean Podman resources (via podman_cleanup role) |
| `disk_maintenance_clean_journal` | `true` | Clean systemd journal logs |
| `disk_maintenance_clean_tmp` | `true` | Clean temporary files |
| `disk_maintenance_clean_package_cache` | `true` | Clean package manager cache (DNF/APT) |
| `disk_maintenance_clean_old_logs` | `true` | Clean old log files |
| `disk_maintenance_journal_max_size` | `"500M"` | Maximum size for journal |
| `disk_maintenance_journal_max_days` | `7` | Keep logs for last N days |
| `disk_maintenance_dnf_clean_all` | `true` | Clean all DNF cache (not just expired) |
| `disk_maintenance_log_max_age_days` | `30` | Remove logs older than N days |

## What Gets Cleaned

1. **Podman Resources** (via `podman_cleanup` role):
   - Stopped containers
   - Unused images
   - Unused networks
   - Build cache

2. **Systemd Journal**:
   - Vacuumed to maximum size
   - Vacuumed to maximum age

3. **Package Cache**:
   - DNF cache (Fedora)
   - APT cache (Debian/Ubuntu)

4. **Temporary Files**:
   - Files in `/tmp` and `/var/tmp` older than configured age

5. **Old Log Files**:
   - Log files in `/var/log` older than configured age

## Safety

- Requires explicit confirmation (`disk_maintenance_confirm: true`)
- Shows before/after disk and inode usage
- Does not remove Podman volumes by default (may contain data)
- Safe to run on production systems

## Tags

- `disk_maintenance` - All maintenance tasks
- `podman` - Podman cleanup only
- `journal` - Journal cleanup only
- `packages` - Package cache cleanup only
- `tmp` - Temporary files cleanup only
- `logs` - Log files cleanup only
- `safety` - Safety checks

## Example Output

```
Disk usage before cleanup:
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  20G   19G  500M  98%  /

Inode usage before cleanup:
Filesystem      Inodes  IUsed  IFree IUse% Mounted on
/dev/nvme0n1p2  5.0M    4.8M   200K  96%   /

[... cleanup operations ...]

Disk usage after cleanup:
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  20G   15G  4.5G  77%  /

Inode usage after cleanup:
Filesystem      Inodes  IUsed  IFree IUse% Mounted on
/dev/nvme0n1p2  5.0M    2.5M   2.5M  50%   /
```




