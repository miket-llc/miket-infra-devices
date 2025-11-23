---
document_title: "OneDrive to /space Migration Rollback Procedures"
author: "Codex-CA-001"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/onedrive-to-space-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# OneDrive to /space Migration Rollback Procedures

**Status:** Published  
**Purpose:** Emergency procedures to rollback migration if critical issues are discovered  
**Owner:** Codex-CA-001 (Chief Architect)

---

## Rollback Scenarios

### Scenario 1: Migration Failure During Execution

**Trigger:** Migration script fails with unrecoverable error

**Procedure:**
1. **Stop Migration**
   ```bash
   sudo pkill -f m365-migrate-to-space.sh
   ```

2. **Verify OneDrive Integrity**
   ```bash
   # List OneDrive content to verify it's intact
   rclone lsd m365-<account>:
   
   # Check for any corruption
   rclone check m365-<account>: /space/journal/m365/<account>/latest
   ```

3. **Document Failure**
   - Review logs: `/var/log/m365-migrate-<account>.log`
   - Document error message and context
   - Identify root cause

4. **Cleanup Partial Migration**
   ```bash
   # Remove partially migrated content (if needed)
   # BE CAREFUL - verify what was migrated first
   sudo rm -rf /space/<account>/<partial-directory>
   ```

5. **Resume or Retry**
   - Fix identified issues
   - Retry migration with fixes applied

---

### Scenario 2: Data Corruption Discovered Post-Migration

**Trigger:** Files corrupted or missing after migration completes

**Procedure:**
1. **Verify Corruption**
   ```bash
   # Compare checksums for critical files
   # Identify which files are corrupted
   ```

2. **Restore from Hoover Backup**
   ```bash
   # Use existing m365-hoover.sh backups
   REPO="/space/journal/m365/<account>/restic-repo"
   
   # List available snapshots
   restic -r "$REPO" snapshots
   
   # Restore specific snapshot
   restic -r "$REPO" restore <snapshot-id> --target /space/<account>/restored
   
   # Verify restored files
   # Copy to correct location
   ```

3. **Re-migrate Affected Files**
   ```bash
   # Use Rclone to sync specific directories
   rclone sync m365-<account>:<path> /space/<account>/<path> \
       --checksum \
       --verbose
   ```

---

### Scenario 3: Disk Space Exhaustion

**Trigger:** `/space` partition runs out of space during migration

**Procedure:**
1. **Stop Migration**
   ```bash
   sudo pkill -f m365-migrate-to-space.sh
   ```

2. **Free Up Space**
   ```bash
   # Check disk usage
   df -h /space
   
   # Identify large directories
   du -sh /space/* | sort -h
   
   # Free up space (options):
   # - Remove temporary files
   # - Archive old data to B2
   # - Expand partition (if possible)
   ```

3. **Resume Migration**
   ```bash
   # Migration script supports resume
   sudo /usr/local/bin/m365-migrate-to-space.sh \
       --account <account> \
       --resume
   ```

---

### Scenario 4: Complete Rollback (Revert to OneDrive as Primary)

**Trigger:** Decision to revert to OneDrive as primary storage

**Procedure:**
1. **Stop All Sync Operations**
   ```bash
   # Disable space-mirror timer
   sudo systemctl stop space-mirror.timer
   sudo systemctl disable space-mirror.timer
   
   # Disable m365-publish (if enabled)
   sudo systemctl stop m365-publish.timer
   sudo systemctl disable m365-publish.timer
   ```

2. **Sync Back to OneDrive**
   ```bash
   # Use Rclone to sync /space back to OneDrive
   rclone sync /space/<account> m365-<account>: \
       --checksum \
       --verbose \
       --progress
   ```

3. **Verify OneDrive Content**
   ```bash
   # Compare file counts and sizes
   rclone size m365-<account>: --json
   du -sh /space/<account>
   ```

4. **Update Documentation**
   - Document rollback decision
   - Update architecture docs
   - Update workflows

---

## Data Recovery Procedures

### From Hoover Backups (Restic)

```bash
# Set repository path
REPO="/space/journal/m365/<account>/restic-repo"

# List snapshots
restic -r "$REPO" snapshots

# Restore latest snapshot
restic -r "$REPO" restore latest --target /space/<account>/restored

# Restore specific snapshot
restic -r "$REPO" restore <snapshot-id> --target /space/<account>/restored

# Restore specific file
restic -r "$REPO" restore latest --target /tmp/restore --include /path/to/file
```

### From B2 Backup

```bash
# List B2 content
rclone lsd b2:miket-space-mirror/<account>/

# Restore from B2
rclone sync b2:miket-space-mirror/<account>/ /space/<account>/restored \
    --checksum \
    --verbose
```

---

## Verification Steps

After any rollback operation:

1. **Verify Source Integrity**
   ```bash
   # OneDrive should be intact
   rclone lsd m365-<account>:
   ```

2. **Verify Destination State**
   ```bash
   # Check /space state
   ls -la /space/<account>/
   ```

3. **Compare File Counts**
   ```bash
   SOURCE=$(rclone size m365-<account>: --json | jq '.count')
   DEST=$(find /space/<account> -type f | wc -l)
   echo "Source: $SOURCE, Destination: $DEST"
   ```

4. **Verify Checksums** (for critical files)
   ```bash
   # Manual verification of critical files
   ```

---

## Emergency Contacts

- **Infrastructure Lead:** Codex-CA-001
- **Storage Engineer:** Codex-IAC-003
- **SRE:** Codex-SRE-005

---

## Prevention Measures

To minimize need for rollback:

1. **Always run dry-run first**
2. **Verify disk space before migration**
3. **Test with small dataset first**
4. **Monitor migration progress continuously**
5. **Keep hoover backups current**
6. **Verify B2 backups before migration**

---

**Related Documentation:**
- [Migration Plan](./MIGRATION_PLAN.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [M365 Restore Runbook](../../runbooks/M365_RESTORE.md)

