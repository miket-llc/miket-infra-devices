---
document_title: "Motoko Disk Maintenance Runbook"
author: "Codex-CA-001"
last_updated: 2025-12-03
status: Published
related_initiatives: []
linked_communications: []
---

# Motoko Disk Maintenance Runbook

**Purpose:** Recover disk space and inodes on motoko when critical alerts are triggered.

**When to Use:**
- Netdata alerts: "Disk / estimation of lack of space" (critical)
- Netdata alerts: "Disk / estimation of lack of inodes" (critical)
- Manual maintenance (monthly recommended)

---

## Quick Start

### Run Full Disk Maintenance

```bash
cd ~/miket-infra-devices
ansible-playbook -i inventory/hosts.yml playbooks/motoko/disk-maintenance.yml
```

This playbook will:
1. Clean Podman unused resources (containers, images, build cache)
2. Vacuum systemd journal logs (keep last 7 days, max 500MB)
3. Clean DNF package cache
4. Remove old temporary files
5. Remove old log files (older than 30 days)

---

## What Gets Cleaned

### 1. Podman Resources
- **Stopped containers**: Removed
- **Unused images**: Removed (keeps images in use)
- **Unused networks**: Removed
- **Build cache**: Removed
- **Volumes**: **NOT removed** (may contain data)

### 2. Systemd Journal
- Vacuumed to maximum size: **500MB**
- Vacuumed to maximum age: **7 days**
- This is often the biggest space/inode consumer

### 3. Package Cache (DNF)
- All DNF cache cleaned (not just expired)
- Typically frees 500MB-2GB

### 4. Temporary Files
- Files in `/tmp` and `/var/tmp` older than 30 days

### 5. Old Log Files
- Log files in `/var/log` older than 30 days
- Excludes journal (handled separately)

---

## Manual Cleanup (If Playbook Fails)

### Check Current Usage

```bash
# Disk space
df -h /

# Inode usage
df -i /

# Journal size
journalctl --disk-usage

# Podman usage
podman system df
```

### Manual Podman Cleanup

```bash
# Remove stopped containers
podman container prune -f

# Remove unused images
podman image prune -f

# Remove build cache
podman builder prune -af

# Remove unused networks
podman network prune -f
```

### Manual Journal Cleanup

```bash
# Vacuum to 500MB
journalctl --vacuum-size=500M

# Vacuum to 7 days
journalctl --vacuum-time=7d
```

### Manual Package Cache Cleanup

```bash
# Clean all DNF cache
dnf clean all
```

---

## Configuration

Settings are in `ansible/host_vars/motoko.yml`:

```yaml
# Podman cleanup settings
podman_cleanup_remove_stopped_containers: true
podman_cleanup_remove_unused_images: true
podman_cleanup_remove_unused_volumes: false  # Keep volumes
podman_cleanup_remove_unused_networks: true
podman_cleanup_remove_build_cache: true

# Disk maintenance settings
disk_maintenance_journal_max_size: "500M"
disk_maintenance_journal_max_days: 7
disk_maintenance_dnf_clean_all: true
disk_maintenance_log_max_age_days: 30
```

---

## Expected Results

After running the maintenance playbook, you should see:

- **Disk space**: 10-30% increase in available space (depending on usage)
- **Inodes**: Significant reduction in inode usage (journal cleanup helps most)
- **Journal size**: Reduced to <500MB
- **Podman**: Only active resources remain

Example output:
```
Disk usage before: 19G used / 20G total (98% full)
Disk usage after:  15G used / 20G total (77% full)

Inode usage before: 4.8M used / 5.0M total (96% full)
Inode usage after:  2.5M used / 5.0M total (50% full)
```

---

## Troubleshooting

### Playbook Fails with "Permission Denied"

Run with `--become` (already included in playbook):
```bash
ansible-playbook -i inventory/hosts.yml playbooks/motoko/disk-maintenance.yml --become
```

### Still Low on Space After Cleanup

1. Check what's consuming space:
   ```bash
   du -sh /space/* | sort -h
   du -sh /podman/* | sort -h
   ```

2. Check for large files:
   ```bash
   find / -type f -size +1G 2>/dev/null | head -20
   ```

3. Check Podman storage location:
   ```bash
   podman info | grep -A 5 "store"
   ```

4. Consider more aggressive cleanup:
   - Reduce `disk_maintenance_journal_max_days` to 3
   - Enable `podman_cleanup_prune_all: true` (removes ALL unused resources)

### Inodes Still High

1. Check inode usage by filesystem:
   ```bash
   df -i
   ```

2. Find directories with many small files:
   ```bash
   find / -xdev -type d | while read dir; do
     count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
     if [ $count -gt 1000 ]; then
       echo "$count $dir"
     fi
   done | sort -rn | head -20
   ```

3. Journal cleanup should help most (systemd-journald creates many small files)

---

## Automation

### Scheduled Maintenance (Recommended)

Add to cron or systemd timer for monthly cleanup:

```yaml
# In ansible/host_vars/motoko.yml or group_vars
# Create a systemd timer that runs monthly
```

Or run manually when alerts trigger.

---

## Safety Notes

- **Volumes are NOT removed** by default (may contain data)
- **Active containers/images are NOT removed** (only unused)
- **Journal logs older than 7 days are removed** (adjust if needed)
- All operations are logged and show before/after usage

---

## Related Documentation

- `ansible/roles/podman_cleanup/README.md` - Podman cleanup role details
- `ansible/roles/disk_maintenance/README.md` - Disk maintenance role details
- `ansible/playbooks/motoko/disk-maintenance.yml` - Main playbook

---

## Revision History

- **2025-12-03**: Initial runbook created for critical disk space/inode alerts




