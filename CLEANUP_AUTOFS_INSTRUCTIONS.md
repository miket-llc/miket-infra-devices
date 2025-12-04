# Autofs Cleanup Instructions

## Why This Matters

The autofs base mount at `/Volumes/motoko` is still active and could cause:
- Mount conflicts if autofs tries to mount when you access /Volumes/motoko
- Confusion about which mount is active
- Potential hang if autofs times out
- Multiple mount points for the same share

**Current State:**
```
✅ Working mounts: ~/.mkt/flux, ~/.mkt/space, ~/.mkt/time
❌ Autofs base still active: /Volumes/motoko (empty but configured)
```

## Quick Cleanup (Run on count-zero)

### Option 1: Run the Script (Recommended)

```bash
# The script is already on count-zero at /tmp/cleanup-autofs-final.sh
chmod +x /tmp/cleanup-autofs-final.sh
sudo /tmp/cleanup-autofs-final.sh
```

### Option 2: Manual Commands

```bash
# Backup config files
sudo cp /etc/auto_master /etc/auto_master.backup-$(date +%Y%m%d)
sudo cp /etc/auto.motoko /etc/auto.motoko.backup-$(date +%Y%m%d) 2>/dev/null || true

# Remove autofs map file
sudo rm -f /etc/auto.motoko

# Remove entry from auto_master
sudo sed -i.cleanup '/^\/Volumes\/motoko/d' /etc/auto_master

# Reload automounter
sudo automount -vc

# Unmount autofs base
sudo umount /Volumes/motoko 2>/dev/null || true
```

## Verify Cleanup

```bash
# Should show NO /Volumes/motoko
mount | grep motoko

# Should show only these three:
# //mdt@motoko/flux on /Users/miket/.mkt/flux
# //mdt@motoko/space on /Users/miket/.mkt/space
# //mdt@motoko/time on /Users/miket/.mkt/time
```

## What Gets Removed

- ❌ `/etc/auto.motoko` - autofs map file (credentials embedded)
- ❌ `/etc/auto_master` entry for `/Volumes/motoko`
- ❌ Autofs base mount at `/Volumes/motoko`

## What Stays (Working)

- ✅ `~/.mkt/flux`, `~/.mkt/space`, `~/.mkt/time` - actual SMB mounts
- ✅ `~/flux`, `~/space`, `~/time` - user symlinks
- ✅ `~/PHC/S`, `~/PHC/T`, `~/PHC/X` - drive letter shortcuts
- ✅ LaunchAgent: `com.miket.storage-connect.plist`

## Rollback (If Needed)

```bash
# Restore from backup
sudo cp /etc/auto_master.backup-YYYYMMDD /etc/auto_master
sudo cp /etc/auto.motoko.backup-YYYYMMDD /etc/auto.motoko
sudo automount -vc
```

## After Cleanup

Once complete, I'll update the documentation to reflect the clean state.

