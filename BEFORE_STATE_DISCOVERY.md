# Phase 0: Discovery Report - BEFORE State

**Date**: 2025-12-04  
**Target**: count-zero (macOS), motoko (server), Windows devices  
**Issue**: Autofs regression causing poor UX on macOS

---

## macOS (count-zero) - Current State

### Mounts (from `mount` command):
```
map /etc/auto.motoko on /Volumes/motoko (autofs, automounted, nobrowse)
//mdt@motoko/space on /Volumes/motoko/space (smbfs, nodev, nosuid, automounted, noowners, nobrowse, mounted by miket)
//mdt@motoko.pangolin-vega.ts.net/time on /Volumes/.timemachine/motoko.pangolin-vega.ts.net/BA4F0496-E2F9-4002-AC1A-E064F30EE69D/time (smbfs, nobrowse)
```

**Analysis**:
- ✅ `space` mounted via autofs at `/Volumes/motoko/space`
- ✅ `time` mounted by Time Machine (NOT via autofs - correct per docs)
- ❌ `flux` NOT mounted (autofs map exists but not triggered)
- ⚠️  Autofs base `/Volumes/motoko` is active

### Autofs Configuration:

**`/etc/auto_master` (active line):**
```
/Volumes/motoko /etc/auto.motoko --timeout=300
```

**`/etc/auto.motoko`:**
- File exists but couldn't read without sudo (contains password)
- Controls autofs mounts for flux/space (NOT time per docs)

### User Experience Elements:

**Home directory symlinks:**
```
lrwxr-xr-x@ 1 root  staff  20 Dec  4 10:20 /Users/miket/flux -> /Volumes/motoko/flux
lrwxr-xr-x@ 1 root  staff  21 Dec  4 10:20 /Users/miket/space -> /Volumes/motoko/space
```
- ✅ `~/flux` and `~/space` symlinks exist (owned by root)
- ❌ `~/time` symlink missing
- ⚠️  Symlinks point to autofs paths

**Legacy structure (~/.mkt):**
```
~/.mkt/flux    - EXISTS but EMPTY
~/.mkt/space   - EXISTS with content (2 subdirs: art, devices)
~/.mkt/time    - EXISTS but EMPTY
~/.mkt/mounts.env - credentials file
```
- ⚠️  Old mount points from original `mount_shares_macos` role
- ⚠️  `~/.mkt/space` has actual data (not a mount, local copy?)
- Nothing actively mounted here

### Time Machine:
```
tmutil destinationinfo:
URL: smb://mdt@motoko.pangolin-vega.ts.net/time
```
- ✅ Using /time share for backups
- ✅ Mounted outside autofs (correct per docs)

### Active Playbook:
- `ansible/playbooks/mount-shares-count-zero.yml` uses `mount_shares_macos_autofs` role

---

## Server (motoko) - Current State

### Samba Configuration (`testparm -s`):

**Global:**
```
workgroup = SAMBA
security = USER
```
- ❌ No macOS-specific VFS modules (fruit, streams_xattr)
- Basic config, functional but not optimized for Mac

**Shares:**
```
[flux]
  comment = Flux - Active workspace
  path = /flux
  valid users = mdt
  writable = yes
  browsable = yes

[space]
  comment = Space - Archive and SoR
  path = /space
  valid users = mdt
  writable = yes
  browsable = yes

[time]
  comment = Time - Backups and history
  path = /time
  valid users = mdt
  writable = yes
  browsable = yes
```

**Analysis**:
- ✅ All 3 shares properly configured
- ✅ Paths exist and are accessible
- ❌ `/time` not marked as Time Machine share (but TM is using it successfully)
- ❌ No `fruit:time machine = yes` or quota settings for TM

### Filesystem Status:
```
/dev/sda1 on /flux type ext4 (rw,noatime,seclabel)
/dev/sdc2 on /space type ext4 (rw,noatime,seclabel)
/dev/sdc1 on /time type ext4 (rw,noatime,seclabel)
```
- ✅ All shares mounted and healthy on server

---

## Windows Devices - Expected State

**Per docs (`ansible/roles/mount_shares_windows/defaults/main.yml`):**
```yaml
smb_shares:
  - name: "flux"
    drive_letter: "X"
  - name: "space"
    drive_letter: "S"
  - name: "time"
    drive_letter: "T"
```

**Expected mappings:**
- `S:` → `\\motoko\space`
- `T:` → `\\motoko\time`
- `X:` → `\\motoko\flux`

*Note: Unable to verify actual state - will validate after changes*

---

## Problems Identified

### Critical Issues:
1. **Autofs causing UX problems** (per mission statement)
2. **flux not mounting** - autofs map exists but share not available
3. **Missing ~/time symlink** - inconsistent with ~/flux and ~/space
4. **Confusing dual structure** - both `~/.mkt/*` and `~/symlinks` exist
5. **No "drive letter" shortcuts** - Windows users have S:/T:/X:, macOS should have equivalent

### Configuration Drift:
1. **Two different mount roles exist**:
   - `mount_shares_macos` (original, uses ~/.mkt mounts)
   - `mount_shares_macos_autofs` (current, uses /Volumes/motoko)
2. **Playbook uses autofs role** but old structure still present
3. **Server lacks macOS optimizations** (fruit VFS modules)

### User Experience Issues:
1. **No Finder sidebar integration** documented
2. **Autofs timeout causes unmounts** after 5 minutes idle
3. **Root-owned symlinks** - should be user-owned
4. **No convenient shortcuts** matching Windows muscle memory (S/T/X)

---

## Recommended Approach (Based on Docs + Discovery)

### Server Changes (Minimal):
1. Add macOS-specific VFS modules to Samba global config
2. Properly mark `/time` share for Time Machine
3. Keep share names and paths UNCHANGED

### macOS Changes (The "Unfuck"):
1. **Remove autofs completely**:
   - Comment out `/Volumes/motoko` line in `/etc/auto_master`
   - Delete `/etc/auto.motoko`
   - Reload: `sudo automount -vc`
   - Unmount ghost autofs mounts

2. **Switch to native macOS mount approach**:
   - Use `mount_shares_macos` role (NOT autofs variant)
   - Mount to `~/.mkt/{flux,space,time}` (user-level, no sudo needed for access)
   - Store credentials in Keychain
   - Use LaunchAgent for auto-mount at login (not autofs)

3. **UX Polish**:
   - Create user-owned symlinks: `~/flux`, `~/space`, `~/time` → `~/.mkt/*`
   - Create "drive letter" shortcuts: `~/PHC/S` → space, `~/PHC/T` → time, `~/PHC/X` → flux
   - Add to Finder sidebar favorites
   - Ensure offline behavior degrades gracefully

4. **Clean up**:
   - Remove old data in `~/.mkt/space` (back up first!)
   - Ensure consistent ownership (user, not root)

---

## Expected End State

### macOS:
- No autofs for space/flux/time
- Mounts at `~/.mkt/{flux,space,time}` via LaunchAgent
- Convenient shortcuts:
  - `~/flux`, `~/space`, `~/time` (symlinks)
  - `~/PHC/S`, `~/PHC/T`, `~/PHC/X` ("drive letters")
- Finder sidebar favorites
- Auto-reconnect after login/sleep/network changes

### Server:
- Samba config with macOS fruit modules
- Time Machine share properly configured
- All existing Windows/Linux clients unchanged

### Windows:
- `S:`, `T:`, `X:` unchanged and working
- No regression

---

## Next Steps

Proceed to Phase 1: Server sanity checks and minimal config updates.

