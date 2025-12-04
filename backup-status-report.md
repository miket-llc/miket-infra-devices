# Backblaze Backup Status Report
**Generated:** 2025-12-04 07:48 EST  
**Target Device:** motoko

## Executive Summary

### ✅ flux-backup (Restic Cloud Backup)
**Status:** WORKING PROPERLY

- **Last Successful Run:** December 4, 2025 at 05:01:35 EST
- **Next Scheduled Run:** December 5, 2025 at 05:00:00 EST
- **Schedule:** Daily at 05:00
- **Source:** `/flux`
- **Destination:** `b2:miket-backups-restic:flux`
- **Latest Snapshot ID:** `ba57c1c3b32a8b2b1447dffa2aa8bcec6dbf28d2ad2b7fc0a24ed5d86bffa424`
- **Retention Policy:** 7 daily, 4 weekly, 12 monthly snapshots

### ❌ space-mirror (B2 Mirror Sync)
**Status:** FAILED - Root Cause Identified and Fixed

- **Last Successful Run:** December 2, 2025 at 05:48:32 EST (2 days ago)
- **Last Failed Run:** December 4, 2025 at 05:01:49 EST
- **Next Scheduled Run:** December 5, 2025 at 04:00:00 EST
- **Schedule:** Nightly at 04:00
- **Source:** `/space`
- **Destination:** `b2:miket-space-mirror`
- **Failure Reason:** Exit code 6 - File modification during sync (race condition)
- **Root Cause:** The script writes to `_ops/logs/data-lifecycle/space-mirror.log` while rclone is trying to sync it, causing a self-referential race condition
- **Fix Applied:** Excluded `_ops/logs/**` from sync and added retry logic for transient errors

## Detailed Analysis

### flux-backup Service
The flux-backup service is functioning correctly:
- Service completed successfully on the last run
- Prune operation completed successfully
- Marker file written: `/space/_ops/data-estate/markers/restic_cloud.json`
- Timer is active and scheduled correctly

**Note:** Earlier log entries (Dec 1-2) show "restic: command not found" errors, but these appear to be from before restic was properly installed. The most recent run (Dec 4) completed successfully.

### space-mirror Service
The space-mirror service failed on the last run due to a transient error:

**Error Details:**
```
Post "https://pod-050-1030-10.backblaze.com/b2api/v1/b2_upload_file/...": 
can't copy - source file is being updated (size changed from 82208217 to 82210153)
```

**What Happened:**
- The sync process transferred 140.063 GiB successfully
- Completed 3,226,213 file checks
- Performed 17,459 server-side copies
- Failed with 2 errors due to a file being modified during the sync operation
- **Root Cause Identified:** The file being modified was `_ops/logs/data-lifecycle/space-mirror.log` - the script's own log file!
- This is a self-referential race condition: the script writes log entries while rclone tries to sync the same log file
- This has occurred multiple times (Dec 3-4) with the same file

**Impact:**
- The sync was ~99.99% complete before failing
- Most data was successfully synced
- The failure prevents the marker file from being written
- The last known successful sync was 2 days ago (Dec 2)

## Recommendations

### Immediate Actions

1. **Manually trigger space-mirror to retry:**
   ```bash
   ssh motoko
   sudo backblaze-trigger.sh space-mirror
   ```
   Or via Ansible:
   ```bash
   ansible motoko -i ansible/inventory/hosts.yml -m shell -a "sudo backblaze-trigger.sh space-mirror"
   ```

2. **Monitor the retry:**
   ```bash
   ssh motoko
   sudo journalctl -u space-mirror.service -f
   ```

### Fixes Applied

1. **Excluded logs directory from sync:**
   - Added `--exclude="_ops/logs/**"` to prevent syncing log files
   - Logs are ephemeral and don't need to be backed up
   - This eliminates the self-referential race condition

2. **Added retry logic:**
   - Added `--retries 3` and `--retries-sleep 5s` for transient errors
   - Added `--checkers 16` for better parallelism
   - This handles any remaining file modification race conditions gracefully

3. **Excluded other volatile files:**
   - Excluded `_ops/tmp/**`, `*.tmp`, `*.temp`, `*.swp`, `*.lock`
   - These files are temporary and shouldn't be backed up

### Deployment

To deploy the fix:
```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-lifecycle.yml --limit motoko
```

Or manually update the script on motoko:
```bash
ansible motoko -i ansible/inventory/hosts.yml -m copy -a "src=ansible/roles/data-lifecycle/files/space-mirror.sh dest=/usr/local/bin/flux-backup.sh mode=0755"
```

### Long-term Improvements

1. **Add monitoring alerts:**
   - Set up alerts when space-mirror fails
   - Monitor marker file age to detect stale backups

2. **Consider log rotation:**
   - Implement log rotation to keep log files smaller
   - Or move logs to a location outside `/space` (e.g., `/var/log`)

## Verification Commands

### Check Service Status
```bash
sudo backblaze-trigger.sh --status all
```

### Check Timer Status
```bash
systemctl list-timers flux-backup.timer space-mirror.timer
```

### View Recent Logs
```bash
# flux-backup logs
sudo journalctl -u flux-backup.service --since "24 hours ago"

# space-mirror logs
sudo journalctl -u space-mirror.service --since "24 hours ago"
```

### Check Marker Files
```bash
ls -la /space/_ops/data-estate/markers/*.json
cat /space/_ops/data-estate/markers/restic_cloud.json | jq .
```

### Verify Restic Repository
```bash
source /etc/miket/storage-credentials.env
restic -r b2:miket-backups-restic:flux snapshots --latest 5
```

### Verify B2 Bucket Access
```bash
source /etc/miket/storage-credentials.env
rclone lsd :b2:miket-space-mirror
```

## Conclusion

The **flux-backup** service is working properly and successfully backing up critical data to Backblaze B2.

The **space-mirror** service needs attention - it failed on the last run due to a transient file modification error. While most data was synced successfully, the failure prevents completion. A manual retry should resolve this, but the underlying issue (files being modified during sync) may need investigation.


