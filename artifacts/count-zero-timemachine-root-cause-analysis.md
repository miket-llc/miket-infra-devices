# Time Machine Backup Failure: Root Cause Analysis

**Date:** 2025-12-05  
**Affected System:** count-zero → motoko Time Machine backups  
**Status:** RESOLVED  
**Investigator:** Codex-SRE-005  

---

## Summary

Time Machine backups from count-zero to motoko's `/time` share stopped working due to **USB drive device name drift** on motoko. The 18.2TB Western Digital external drive changed device names (from `sdb`/`sdc` to `sdd`) after a system event, causing stale mounts with I/O errors that blocked all access to `/time` and `/space`.

## Timeline

| Time | Event |
|------|-------|
| Unknown | USB drive device names changed (likely after reboot or replug) |
| Unknown | Stale mounts to old device names (sdb1, sdc1) accumulated |
| 2025-12-05 11:18 | Investigation started - Time Machine showing "Failed to mount destination" |
| 2025-12-05 11:19 | Root cause identified - `/time` returning I/O errors |
| 2025-12-05 11:19 | Fix applied - Samba stopped, stale mounts cleared, remounted via UUID |
| 2025-12-05 11:20 | Time Machine backup started successfully |
| 2025-12-05 11:25 | Backup progressed to Copying phase (confirmed working) |

## Root Cause

### Technical Details

1. **Device Name Drift:** The 18.2TB WD external USB drive was originally assigned `/dev/sdb` and `/dev/sdc` but changed to `/dev/sdd` after a system event (reboot, USB replug, or power cycle).

2. **Stale Mounts:** The kernel retained mount table entries pointing to the old device names:
   ```
   /dev/sdb1 on /time type ext4 (rw,noatime,seclabel,shutdown)
   /dev/sdc1 on /time type ext4 (rw,noatime,seclabel,emergency_ro,shutdown)
   ```

3. **I/O Errors:** Attempts to access `/time` routed to non-existent devices, causing:
   - EXT4 htree read errors (inode #2, lblock 0)
   - `emergency_ro` flag set (kernel filesystem protection)
   - All directory listings returning "Input/output error"

4. **Cascading Failure:** 
   - Samba couldn't read `/time` contents
   - Time Machine couldn't mount the sparsebundle
   - Client-side SMB connections became stale
   - Backup failed with "Failed to mount destination" (Error Code 26)

### Evidence

```
# dmesg showed repeated errors:
EXT4-fs warning (device sdc1): htree_dirblock_to_tree:1051: inode #2: 
    lblock 0: comm smbd: error -5 reading directory block

# Mount table showed double-mount with error flags:
/dev/sdb1 on /time type ext4 (rw,noatime,seclabel,shutdown)
/dev/sdc1 on /time type ext4 (rw,noatime,seclabel,emergency_ro,shutdown)

# lsblk showed correct device (sdd) not mounted:
sdd                18.2T disk                        WDC WD200EDGZ-11BLDS0    
├─sdd1              7.3T part ext4                   f54cf57c-e434-45f5-...  # Should be /time
└─sdd2             10.9T part ext4                   7f5e508d-fcac-4d18-...  # Should be /space

# fstab correctly uses UUIDs (not device names):
UUID=f54cf57c-e434-45f5-bde3-cc706ffbe849 /time ext4 defaults,noatime 0 2
UUID=7f5e508d-fcac-4d18-80ca-84c857b20b40 /space ext4 defaults,noatime 0 2
```

## Resolution

### Immediate Fix Applied

1. Stopped Samba service to release mount handles
2. Force-unmounted stale mounts with `umount -l /time` (multiple times)
3. Remounted `/time` and `/space` using fstab (UUID-based)
4. Restarted Samba
5. Triggered Time Machine backup from count-zero

### Verification

```bash
# After fix - clean mount state:
/dev/sdd1 on /time type ext4 (rw,noatime,seclabel)
/dev/sdd2 on /space type ext4 (rw,noatime,seclabel)

# Directory access working:
ls /time/
count-zero.sparsebundle  .DS_Store  lost+found

# Samba serving connections:
Service      pid     Machine       Connected at
time         1553423 100.108.127.57 Fri Dec  5 11:20:28 AM 2025 EST

# Time Machine backup progressing:
BackupPhase = Copying
Percent = 0.19...
bytes = 7259869184
totalBytes = 3829721825280
```

## Changes Made (Code-First)

### New Scripts Created

1. **`scripts/check-motoko-storage-health.sh`**
   - Health check for critical mounts (/time, /space, /flux)
   - Detects stale/duplicate mounts
   - Verifies mount accessibility
   - Optional `--fix` mode for auto-remediation

2. **`scripts/fix-motoko-storage-mounts.sh`**
   - Recovery script for mount failures
   - Stops Samba, clears stale mounts, remounts from fstab
   - Restarts Samba and verifies recovery

### Documentation Updated

- **`docs/runbooks/troubleshoot-timemachine-smb.md`**
  - Added Section 6: USB Drive Device Name Drift
  - Updated server-side checks (smb vs smbd on Fedora)
  - Enhanced Related Files and Prevention sections

## Architecture Invariants Respected

| Invariant | Status |
|-----------|--------|
| IaC for durable changes | ✅ Scripts added to repo, no manual config edits |
| Secrets via AKV | ✅ No credential changes needed |
| Storage invariants | ✅ /space and /time unchanged, backup data preserved |
| Tailnet connectivity | ✅ Used Tailscale hostnames throughout |
| mdt automation account | ✅ All operations via mdt user |

## Risk & Follow-ups

### Residual Risks

1. **USB instability:** External USB drives inherently less stable than internal disks
2. Future USB device name drift remains possible (mitigated by hourly health checks)

### Completed Follow-ups (2025-12-05)

1. **[x] Add systemd timer** for `check-motoko-storage-health.sh` (hourly)
   - Deployed: `motoko-storage-health.timer` (runs hourly + 2min after boot)
   - Auto-fix mode enabled: will attempt to remount failed mounts
   - Logs to journald: `journalctl -u motoko-storage-health.service`

2. **[x] Add monitoring alerts** for storage and services
   - Created: `tools/monitoring/alerts/motoko.yml`
   - Alerts: MotokoStorageMountFailed, MotokoStorageSpaceLow, MotokoSambaDown, etc.

3. **[x] Document USB drive hardware info**
   - Updated: `devices/motoko/config.yml` with full hardware details
   - Model: WDC WD200EDGZ-11BLDS0, Serial: STGVU4GW
   - UUIDs documented for both /time and /space partitions

### Remaining Considerations

1. **[ ] Consider internal storage** for /time if USB proves unreliable long-term
2. **[ ] Monitor backup success rate** over the next few weeks

## Validation Checklist

- [x] Manual backup from count-zero started successfully
- [x] Backup progressing (Copying phase, 43%+ complete as of 11:49 EST)
- [x] motoko shows SMB connections from count-zero
- [x] No EXT4 errors in dmesg after fix
- [x] No PHC invariants violated
- [x] Systemd timer deployed and running (motoko-storage-health.timer)
- [x] Health check script working (all mounts healthy)
- [ ] Automatic scheduled backup fires and completes (pending - hourly schedule)

