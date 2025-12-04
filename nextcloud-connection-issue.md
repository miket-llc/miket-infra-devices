# Nextcloud Connection Issue - Root Cause Analysis

**Date:** 2025-12-04  
**Issue:** Nextcloud client on count-zero cannot connect - HTTP 403/500 errors  
**Root Cause:** Btrfs filesystem mounted read-only, preventing Nextcloud from reading configuration files

## Problem Summary

The Nextcloud client on count-zero is unable to connect because:

1. **Server returns HTTP 403 Forbidden** - Apache error: "Server unable to read htaccess file, denying access to be safe"
2. **Root cause:** `/dev/nvme0n1p3` (btrfs filesystem containing `/podman`) is mounted **read-only**
3. **Impact:** Nextcloud cannot read its `.htaccess` files, so Apache denies all access for security

## Current State

- **Nextcloud containers:** Running (but can't write to storage)
- **Filesystem:** `/podman` mounted as `ro` (read-only)
- **Error:** `Error: configure storage: open /podman/storage.lock: read-only file system`
- **HTTP Response:** 403 Forbidden (Apache can't read `.htaccess`)

## Diagnosis Commands

```bash
# Check filesystem mount status
mount | grep podman
# Shows: /dev/nvme0n1p3 on /podman type btrfs (ro,...)

# Check for filesystem errors
dmesg | grep -i "read-only\|filesystem.*error"

# Check btrfs filesystem status
btrfs filesystem show /podman
```

## Fix Required

The btrfs filesystem needs to be checked and remounted read-write:

```bash
# 1. Check filesystem (requires unmounting or --force)
sudo btrfs check --readonly /dev/nvme0n1p3

# 2. If errors found, repair (WARNING: may require unmounting)
sudo btrfs check --repair /dev/nvme0n1p3  # Only if safe to do so

# 3. Remount as read-write
sudo mount -o remount,rw /podman

# 4. Restart Nextcloud
cd /flux/apps/nextcloud
sudo podman compose restart

# 5. Verify
curl http://localhost:8080/status.php
```

**⚠️ WARNING:** Filesystem repair may require:
- Unmounting the filesystem (which will stop all containers)
- Potentially a reboot if filesystem is corrupted
- Data backup before repair

## Alternative: Use /space for Podman Storage

If `/podman` filesystem is permanently damaged, consider moving podman storage to `/space`:

```bash
# Update podman storage config
# See: /etc/containers/storage.conf.d/00-custom-storage.conf
```

## Verification

After fix:
1. Filesystem mounted as `rw` (read-write)
2. Nextcloud returns HTTP 200 with JSON status
3. Client on count-zero can connect successfully

## Related Issues

- Podman storage lock errors
- Nextcloud service failing to start (permission denied on env file)
- Container exec commands failing

All stem from the read-only filesystem issue.


