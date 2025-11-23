---
document_title: "OneDrive to /space Migration Plan"
author: "Codex-CA-001"
last_updated: 2025-11-23
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
- **Current Backup:** `m365-hoover.sh` creates versioned snapshots in `/space/journal/m365/<account>/restic-repo`
- **Current Sync:** `m365-publish.sh` publishes approved slices FROM `/space` TO OneDrive

### `/space` Architecture (Target)
- **Location:** `/space` on motoko (Ubuntu 24.04.2 LTS)
- **Mount:** Primary archival storage (Source of Record)
- **Structure:** Organized by user, project, and data type
- **Backup:** Nightly mirror to Backblaze B2 (`miket-space-mirror`)
- **Access:** Samba shares (`\\motoko\space`)

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
- OneDrive root → `/space/mike/` (or appropriate user directory)
- OneDrive/Documents → `/space/mike/Documents/`
- OneDrive/Desktop → `/space/mike/Desktop/`
- OneDrive/Pictures → `/space/mike/Pictures/`
- OneDrive/Shared → `/space/shared/` (if applicable)

---

## Migration Strategy

### Phase 1: Assessment & Preparation
1. **Inventory OneDrive Content**
   - List all accounts with OneDrive data
   - Calculate total data size per account
   - Identify file types and structures
   - Document any special folders or permissions

2. **Verify `/space` Capacity**
   - Ensure sufficient disk space on motoko
   - Verify B2 backup capacity
   - Check Samba share configuration

3. **Prepare Migration Environment**
   - Verify Rclone M365 remotes are configured
   - Test connectivity to OneDrive
   - Create migration staging directory
   - Set up logging infrastructure

### Phase 2: Dry Run Migration
1. **Test Migration Script**
   - Run migration on small test dataset
   - Verify file integrity (checksums)
   - Test conflict resolution logic
   - Validate directory structure

2. **Performance Testing**
   - Measure transfer rates
   - Identify bottlenecks
   - Optimize parallel transfers
   - Test resume capability

### Phase 3: Production Migration
1. **Execute Migration**
   - Run migration script per account
   - Monitor progress and logs
   - Handle errors and retries
   - Verify data integrity

2. **Post-Migration Validation**
   - Compare file counts and sizes
   - Verify checksums for critical files
   - Test file access via Samba
   - Validate backup to B2

### Phase 4: Cutover & Cleanup
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

### Script: `m365-migrate-to-space.sh`

**Purpose:** Migrate all content from OneDrive to `/space` with conflict resolution

**Features:**
- Rclone-based migration (handles M365 authentication)
- Parallel transfers for performance
- Conflict resolution (rename, skip, or overwrite)
- Progress tracking and logging
- Resume capability (checkpoint-based)
- Integrity verification (checksums)
- Dry-run mode for testing

**Usage:**
```bash
# Dry run
./m365-migrate-to-space.sh --account mike --dry-run

# Production migration
./m365-migrate-to-space.sh --account mike --dest /space/mike

# Resume interrupted migration
./m365-migrate-to-space.sh --account mike --resume
```

**Conflict Resolution:**
- **Default:** Rename with timestamp suffix (`file.txt` → `file.txt.2025-11-23-123456`)
- **Options:** `--skip-existing`, `--overwrite`, `--rename`
- **Logging:** All conflicts logged to `/var/log/m365-migrate-<account>.log`

---

## Ansible Automation

### Role: `onedrive-migration`

**Location:** `ansible/roles/onedrive-migration/`

**Tasks:**
1. Deploy migration script to motoko
2. Configure Rclone remotes (if not already configured)
3. Create target directories in `/space`
4. Execute migration with proper error handling
5. Validate migration results
6. Update systemd services (if needed)

**Playbook:** `ansible/playbooks/motoko/migrate-onedrive-to-space.yml`

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

