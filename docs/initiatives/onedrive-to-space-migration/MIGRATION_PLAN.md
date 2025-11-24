---
document_title: "OneDrive to /space Migration Plan"
author: "Codex-CA-001"
last_updated: 2025-11-24
status: Published
related_initiatives:
  - initiatives/onedrive-to-space-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# OneDrive to /space Migration Plan

**Status:** Published  
**Target:** Migrate all content from MikeT LLC OneDrive for Business to `/space` drive on motoko  
**Owner:** Codex-CA-001 (Chief Architect)  
**Date:** November 23, 2025

---

## Executive Summary

This initiative migrates all data from Microsoft 365 OneDrive for Business to the `/space` drive on motoko, establishing `/space` as the canonical Source of Record (SoR) for all organizational data. This aligns with the Flux/Time/Space file system architecture documented in `miket-infra`.

**Key Objectives:**
1. Migrate all OneDrive content to `/space` with proper directory structure
2. Preserve file metadata (timestamps, permissions where applicable)
3. Handle conflicts and edge cases gracefully
4. Establish `/space` as the primary data location
5. Update sync workflows to reflect new architecture

---

## Current State

### OneDrive Architecture
- **Service:** Microsoft 365 OneDrive for Business
- **Tenant:** miketllc.onmicrosoft.com
- **Accounts:** Multiple user accounts with OneDrive storage
- **Local Sync:** OneDrive client syncs to `~/Library/CloudStorage/OneDrive-MikeTLLC/` on count-zero (macOS)
- **Key Content:** `_MAIN_FILES` folder (~4GB) containing organizational data
- **Current Backup:** `m365-hoover.sh` creates versioned snapshots in `/space/journal/m365/<account>/restic-repo`
- **Current Sync:** `m365-publish.sh` publishes approved slices FROM `/space` TO OneDrive

### `/space` Architecture (Target)
- **Location:** `/space` on motoko (Ubuntu 24.04.2 LTS)
- **Mount:** Primary archival storage (Source of Record - SoR)
- **Structure:** Organized by user, project, and data type
- **Backup:** Nightly mirror to Backblaze B2 (`miket-space-mirror`)
- **Access:** Samba shares (`\\motoko\space`)
- **PHC Invariant:** `/space` is the System of Record; OneDrive is collaboration surface only

---

## Target Directory Structure

After migration, OneDrive content will be organized under `/space` as follows:

```
/space/
├── mike/                    # Personal user tree (canonical)
│   ├── Documents/          # Migrated from OneDrive/Documents
│   ├── Desktop/            # Migrated from OneDrive/Desktop
│   ├── Pictures/           # Migrated from OneDrive/Pictures
│   ├── work/               # Work-related content
│   └── ...                 # Other OneDrive folders
├── devices/                 # OS cloud synchronization backend
│   └── onedrive-migration/ # Migration artifacts and logs
├── journal/                 # Versioned snapshots (existing)
│   └── m365/               # Existing hoover backups
│       └── <account>/       # Per-account Restic repos
└── projects/                # Graduated projects
```

**Migration Mapping:**
- OneDrive `_MAIN_FILES` → `/space/mike/_MAIN_FILES/` (primary migration target)
- OneDrive root → `/space/mike/` (or appropriate user directory)
- OneDrive/Documents → `/space/mike/Documents/`
- OneDrive/Desktop → `/space/mike/Desktop/`
- OneDrive/Pictures → `/space/mike/Pictures/`
- OneDrive/Shared → `/space/shared/` (if applicable)

**PHC Compliance:**
- `/space` is the System of Record (SoR) - OneDrive is collaboration surface only
- OS cloud sync continues to `/space/devices/<host>/<user>/` for ongoing ingestion
- Migration transfers historical content directly to `/space/<user>/` for canonical storage
- No circular sync loops - one-way flow: OneDrive → `/space`

---

## Migration Strategy

**Critical Sequencing:** To avoid conflicts with hoover/rclone processes, migration follows this order:
1. **Phase 1:** Transfer from count-zero local OneDrive sync to `/space` (no cloud access needed)
2. **Phase 2:** Compare cloud (M365) with local transfer, merge cloud-only files
3. **Phase 3:** Resume/coordinate with hoover/rclone processes

### Phase 0: Pre-Migration Coordination
1. **Identify Conflicting Processes**
   - Check for `m365-hoover@<account>.timer` (active timers found: `m365-hoover@mike.timer`)
   - Check for `m365-publish.timer` (active timer found)
   - Check for `rclone` M365 sync processes
   - Document any scheduled backups that might conflict

2. **Conflict Resolution Strategy**
   - **Phase 1 (Local Transfer):** No conflicts - reads from count-zero local filesystem only
   - **Phase 2 (Cloud Merge):** Uses `rclone copy` (read-only from cloud) - safe to run alongside hoover
   - **Migration script detects conflicts and prompts user** if active processes found
   - **Recommendation:** Run migration during off-hours or temporarily pause hoover if concerned

3. **Hoover Process Coordination**
   - `m365-hoover@mike.timer` runs nightly at 02:15 (creates Restic snapshots)
   - `m365-publish.timer` runs nightly at 06:00 (publishes FROM `/space` TO OneDrive)
   - Migration reads FROM OneDrive, so hoover is safe (both read from cloud)
   - Migration writes TO `/space`, so publish is safe (publish reads from `/space`)
   - **No destructive operations** - migration uses `rsync` and `rclone copy` (not `sync`)

### Phase 1: Assessment & Preparation
1. **Inventory OneDrive Content**
   - Identify local OneDrive sync locations on client devices
   - Calculate total data size per account/folder
   - Identify file types and structures (e.g., `_MAIN_FILES` on count-zero)
   - Document any special folders or permissions

2. **Verify `/space` Capacity**
   - Ensure sufficient disk space on motoko (11TB available)
   - Verify B2 backup capacity
   - Check Samba share configuration
   - Verify Tailscale connectivity between count-zero and motoko

3. **Prepare Migration Environment**
   - Verify Tailscale SSH access from count-zero to motoko
   - Create migration staging directory on motoko
   - Set up observable logging infrastructure with progress tracking
   - Prepare rsync-based transfer with resume capability

### Phase 2: Dry Run Migration
1. **Test Transfer Script**
   - Run dry-run on `_MAIN_FILES` folder (~4GB)
   - Verify rsync command construction
   - Test Tailscale SSH connectivity
   - Validate directory structure and permissions

2. **Observability Setup**
   - Verify progress output format
   - Test status JSON file generation
   - Validate log file rotation
   - Test resume capability with partial files

### Phase 3: Production Migration

**Phase 3a: Local Transfer (count-zero → /space)**
1. **Execute Local Transfer**
   - Run transfer script for `_MAIN_FILES` from count-zero local OneDrive sync
   - Source: `count-zero:/Users/<user>/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES`
   - Destination: `/space/<user>/_MAIN_FILES`
   - Monitor real-time progress via terminal and status JSON
   - Handle errors and retries (automatic via rsync `--partial`)
   - Verify data integrity with checksums
   - **No cloud access required** - avoids conflicts with hoover/rclone

**Phase 3b: Cloud Merge (M365 → /space)**
2. **Identify Cloud-Only Files**
   - Compare M365 cloud content with local transfer
   - List files in cloud that don't exist in local transfer
   - Generate merge plan (cloud-only files to copy)

3. **Merge Cloud-Only Files**
   - Use `rclone copy` (not `sync`) to merge without deleting
   - Copy cloud-only files to `/space/<user>/`
   - Preserve local transfer as base
   - Monitor progress and verify integrity

2. **Observability During Transfer**
   - Monitor `/var/log/onedrive-transfer-<account>.log` for detailed progress
   - Watch `/var/lib/miket/onedrive-transfer-<account>.json` for status updates
   - Track transfer rate and ETA via rsync progress output
   - Monitor disk space usage on motoko

3. **Post-Migration Validation**
   - Compare file counts and sizes (source vs destination)
   - Verify checksums for critical files
   - Test file access via Samba (`\\motoko\space`)
   - Validate backup to B2 includes migrated content

### Phase 4: Post-Migration Merge
1. **Merge _MAIN_FILES into /space/mike**
   - After Phase 1 transfer completes, merge contents of `/space/mike/_MAIN_FILES/` into `/space/mike/`
   - Handle conflicts: merge directories, rename conflicting files
   - Script: `scripts/merge-main-files-to-space.sh`
   - Usage: `./merge-main-files-to-space.sh --dest /space/mike --conflict-resolution merge`

2. **Conflict Resolution**
   - **Directories:** Merge contents (rsync merge)
   - **Files:** Rename with timestamp suffix (`.from-main-files-YYYYMMDD-HHMMSS`)
   - **Option:** Use `--conflict-resolution skip` to skip conflicts if needed

### Phase 5: Cutover & Cleanup
1. **Update Workflows**
   - Disable or modify `m365-publish.sh` (no longer needed for OneDrive)
   - Update `m365-hoover.sh` to reference new locations
   - Document new sync patterns

2. **Archive OneDrive**
   - Keep OneDrive as read-only backup for 90 days
   - Document archive location
   - Schedule cleanup after validation period

---

## Migration Script Design

### Script: `transfer-onedrive-to-space.sh`

**Purpose:** Transfer OneDrive content from client devices to `/space` on motoko

**Features:**
- Rsync-based transfer over Tailscale SSH (observable progress)
- Parallel transfers for performance
- Conflict resolution (rename, skip, or overwrite)
- Real-time progress tracking with `--progress` and `--info=progress2`
- Resume capability (rsync's `--partial` and `--partial-dir`)
- Integrity verification (checksums via `--checksum`)
- Dry-run mode for testing
- Comprehensive logging to `/var/log/onedrive-transfer-<account>.log`

**Usage:**
```bash
# Dry run
./transfer-onedrive-to-space.sh --source count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES --dest /space/mike/_MAIN_FILES --dry-run

# Production migration
./transfer-onedrive-to-space.sh --source count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES --dest /space/mike/_MAIN_FILES

# Resume interrupted migration (automatic via rsync --partial)
./transfer-onedrive-to-space.sh --source count-zero:/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES --dest /space/mike/_MAIN_FILES
```

**Observability:**
- Real-time progress output to terminal and log file
- Periodic status updates (file count, bytes transferred, ETA)
- JSON status file at `~/.local/state/miket/onedrive-transfer-<account>.json` for monitoring
- Integration with Ansible for orchestration
- Log file at `~/.local/log/onedrive-transfer-<account>.log` (user-writable, no sudo required)

**Conflict Avoidance:**
- Phase 1 (local transfer): No cloud access - safe to run anytime
- Phase 2 (cloud merge): Uses `rclone copy` (read-only from cloud, write to `/space`)
- Detects active hoover/publish processes and prompts user
- Non-destructive operations only (no `sync` or `delete` operations)

**Conflict Resolution:**
- **Default:** Rename with timestamp suffix (`file.txt` → `file.txt.2025-11-23-123456`)
- **Options:** `--skip-existing`, `--overwrite`, `--rename`
- **Logging:** All conflicts logged to `/var/log/m365-migrate-<account>.log`

---

## Ansible Automation

### Role: `onedrive-migration`

**Location:** `ansible/roles/onedrive-migration/`

**Tasks:**
1. Deploy transfer script to motoko (`transfer-onedrive-to-space.sh`)
2. Verify Tailscale connectivity between source and motoko
3. Create target directories in `/space`
4. Execute transfer with proper error handling and observability
5. Validate transfer results (file counts, sizes, checksums)
6. Update systemd services (if needed)

**Playbook:** `ansible/playbooks/motoko/migrate-onedrive-to-space.yml`

**Observability Integration:**
- Status JSON file at `/var/lib/miket/onedrive-transfer-<account>.json` for monitoring
- Log file at `/var/log/onedrive-transfer-<account>.log` for detailed progress
- Real-time progress output to terminal during execution

---

## Risk Assessment

### High Risk
- **Data Loss:** Mitigated by pre-migration backup via `m365-hoover.sh`
- **Disk Space:** Mitigated by capacity verification in Phase 1
- **Authentication Failures:** Mitigated by testing Rclone remotes before migration

### Medium Risk
- **File Conflicts:** Mitigated by conflict resolution strategy
- **Performance Issues:** Mitigated by parallel transfers and resume capability
- **Metadata Loss:** Some metadata may not transfer (acceptable for archival)

### Low Risk
- **Service Disruption:** Migration runs during maintenance window
- **Backup Impact:** B2 mirror runs nightly (separate from migration)

---

## Rollback Plan

If migration fails or issues are discovered:

1. **Immediate Rollback:**
   - Stop migration script
   - Verify OneDrive content is intact
   - Document issues encountered

2. **Data Recovery:**
   - Use existing `m365-hoover.sh` backups in `/space/journal/m365/`
   - Restore from Restic snapshots if needed
   - Verify data integrity

3. **Investigation:**
   - Review migration logs
   - Identify root cause
   - Fix issues and retry migration

---

## Success Criteria

- [ ] All OneDrive accounts migrated successfully
- [ ] File counts match between source and destination
- [ ] Critical files verified with checksums
- [ ] Directory structure matches specification
- [ ] Samba shares accessible and functional
- [ ] B2 backup includes migrated content
- [ ] Documentation updated
- [ ] Workflows updated to reflect new architecture

---

## Timeline

- **Week 1:** Assessment & Preparation (Phase 1)
- **Week 2:** Dry Run & Testing (Phase 2)
- **Week 3:** Production Migration (Phase 3)
- **Week 4:** Cutover & Validation (Phase 4)

**Total Duration:** 4 weeks

---

## Dependencies

- Rclone configured with M365 remotes
- Sufficient disk space on motoko `/space` partition
- B2 backup capacity verified
- Samba shares configured and accessible
- Existing `m365-hoover.sh` backups as safety net

---

## Related Documentation

- [Data Lifecycle Specification](../../../miket-infra/docs/product/initiatives/data-lifecycle/DATA_LIFECYCLE_SPEC.md)
- [Storage Backplane ADR](../../../miket-infra/docs/architecture/adr-logs/ADR-0003-storage-backplane.md)
- [M365 Restore Runbook](../../runbooks/M365_RESTORE.md)

---

**Next Steps:**
1. Review and approve migration plan
2. Execute Phase 1: Assessment & Preparation
3. Schedule migration window
4. Execute migration with monitoring

