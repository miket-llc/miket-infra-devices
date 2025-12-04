---
document_title: "Access Autofs Shares in Finder"
author: "Codex-UX-010"
last_updated: 2025-12-04
status: Published
related_initiatives:
  - initiatives/autofs-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# Access Autofs Shares in Finder

**Status:** Published  
**Purpose:** Guide for accessing autofs-mounted SMB shares in macOS Finder  
**Target:** macOS workstations using autofs (count-zero, etc.)

---

## Overview

With autofs, SMB shares (`time`, `space`, `flux`) are mounted on-demand at `/Volumes/motoko/` and accessible via symlinks in your home directory (`~/flux`, `~/space`, `~/time`). However, autofs mounts don't automatically appear in Finder's sidebar like traditional SMB mounts.

## Quick Access Methods

### Method 1: Use the Symlinks Directly

The easiest way is to use the symlinks in your home directory:

1. **Open Finder**
2. **Press `Cmd+Shift+H`** (or Go → Home)
3. **Click on `flux`, `space`, or `time`** symlinks
4. The share will mount automatically when accessed

### Method 2: Add to Finder Sidebar

**Option A: Drag to Sidebar**

1. Open Finder
2. Press `Cmd+Shift+H` to go to Home
3. **Drag** the `flux`, `space`, or `time` symlinks to the Finder sidebar
4. They'll appear under "Favorites"

**Option B: Use the Script**

Run the automated script:

```bash
cd ~/miket-infra-devices
./scripts/add-autofs-shares-to-finder.sh
```

This script:
- Ensures symlinks exist
- Triggers mounts
- Adds shares to Finder sidebar
- Creates desktop aliases

### Method 3: Create Desktop Aliases

1. Open Finder
2. Navigate to your home directory (`Cmd+Shift+H`)
3. **Right-click** on `flux`, `space`, or `time`
4. Select **"Make Alias"**
5. **Drag the alias** to your Desktop

### Method 4: Use Go Menu

1. In Finder, press `Cmd+Shift+G` (Go → Go to Folder)
2. Type: `~/space`, `~/flux`, or `~/time`
3. Press Enter
4. The share will mount and open

### Method 5: Add to Finder Toolbar

1. Open Finder
2. Navigate to `~/space` (or flux/time)
3. **Drag the folder icon** from the title bar to the Finder toolbar
4. It will appear as a button

## Understanding Autofs Mounts

### Mount Locations

- **System mounts:** `/Volumes/motoko/flux`, `/Volumes/motoko/space`, `/Volumes/motoko/time`
- **User symlinks:** `~/flux`, `~/space`, `~/time`
- **Mount trigger:** Shares mount automatically when accessed (on-demand)
- **Unmount:** After 5 minutes of inactivity (configurable)

### Why Autofs?

Autofs provides:
- **No stale mounts** - Handles disconnections gracefully
- **On-demand mounting** - Only mounts when you access the share
- **Automatic unmounting** - Frees resources when idle
- **Better reliability** - Avoids kernel issues with stale CIFS mounts

## Troubleshooting

### Shares Don't Appear in Finder

**Check if symlinks exist:**
```bash
ls -la ~/flux ~/space ~/time
```

**Trigger mounts manually:**
```bash
ls ~/space ~/flux ~/time
```

**Check autofs status:**
```bash
mount | grep autofs
mount | grep smbfs
```

**Reload autofs:**
```bash
sudo automount -vc
```

### Can't Access Shares

**Verify autofs is configured:**
```bash
cat /etc/auto.motoko
```

**Check mount base exists:**
```bash
ls -ld /Volumes/motoko
```

**Test SMB connectivity:**
```bash
smbclient -L //motoko -U mdt
```

### Finder Sidebar Not Updating

1. **Restart Finder:**
   ```bash
   killall Finder
   ```

2. **Manually add to sidebar:**
   - Open Finder
   - Go to Home (`Cmd+Shift+H`)
   - Drag symlinks to sidebar

3. **Use the script:**
   ```bash
   ./scripts/add-autofs-shares-to-finder.sh
   ```

## Best Practices

1. **Use symlinks** (`~/flux`, `~/space`, `~/time`) - They're the most reliable
2. **Add to Finder sidebar** - For quick access
3. **Don't rely on `/Volumes/motoko`** - It may not exist until mounts are triggered
4. **Let autofs handle mounting** - Don't manually mount/unmount

## Related Documentation

- [macOS Autofs Migration Guide](../architecture/macos-autofs-migration.md)
- [Mount Shares macOS Autofs Role](../../ansible/roles/mount_shares_macos_autofs/README.md)
- [Migrate count-zero to Autofs](../../runbooks/migrate-count-zero-to-autofs.md)

---

## Quick Reference

| Share | Symlink | Mount Point | Purpose |
|-------|---------|-------------|---------|
| flux | `~/flux` | `/Volumes/motoko/flux` | Runtime data (apps, DBs, models) |
| space | `~/space` | `/Volumes/motoko/space` | System of Record (all files) |
| time | `~/time` | `/Volumes/motoko/time` | Time Machine backups |

**Access:** Use `~/flux`, `~/space`, `~/time` symlinks - they mount automatically!

