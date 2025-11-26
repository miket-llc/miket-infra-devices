---
document_title: "OneDrive to /space Migration Initiative"
author: "Codex-CA-001"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/onedrive-to-space-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-onedrive-migration
---

# OneDrive to /space Migration Initiative

**Status:** Published  
**Owner:** Codex-CA-001 (Chief Architect)  
**Date:** November 23, 2025

---

## Overview

This initiative migrates all content from Microsoft 365 OneDrive for Business to the `/space` drive on motoko, establishing `/space` as the canonical Source of Record (SoR) for all organizational data per the Flux/Time/Space file system architecture.

## Documentation

- **[Migration Plan](./MIGRATION_PLAN.md)** - Comprehensive migration strategy and architecture
- **[Deployment Guide](./DEPLOYMENT_GUIDE.md)** - Step-by-step execution procedures
- **[Rollback Procedures](./ROLLBACK_PROCEDURES.md)** - Emergency rollback and recovery procedures
- **[Migration Runbook](../runbooks/onedrive-to-space-migration.md)** - Operational runbook for day-to-day operations

## Quick Start

### Dry Run

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike dry_run=true"
```

### Production Migration

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike"
```

## Components

### Migration Script

**Location:** `scripts/m365-migrate-to-space.sh`

**Features:**
- Rclone-based migration with conflict resolution
- Parallel transfers for performance
- Resume capability for interrupted migrations
- Dry-run mode for testing
- Comprehensive logging and validation

### Ansible Automation

**Role:** `ansible/roles/onedrive-migration/`  
**Playbook:** `ansible/playbooks/motoko/migrate-onedrive-to-space.yml`

**Features:**
- Automated deployment and execution
- Prerequisites validation
- Progress monitoring
- Error handling

## Migration Phases

1. **Phase 1: Assessment & Preparation** - Inventory content, verify capacity
2. **Phase 2: Dry Run Migration** - Test migration on small dataset
3. **Phase 3: Production Migration** - Execute migration with monitoring
4. **Phase 4: Cutover & Cleanup** - Update workflows, archive OneDrive

## Success Criteria

- [ ] All OneDrive accounts migrated successfully
- [ ] File counts match between source and destination
- [ ] Critical files verified with checksums
- [ ] Directory structure matches specification
- [ ] Samba shares accessible and functional
- [ ] B2 backup includes migrated content
- [ ] Documentation updated
- [ ] Workflows updated to reflect new architecture

## Related Documentation

- [Data Lifecycle Specification](../../../miket-infra/docs/product/initiatives/data-lifecycle/DATA_LIFECYCLE_SPEC.md)
- [Storage Backplane ADR](../../../miket-infra/docs/architecture/adr-logs/ADR-0003-storage-backplane.md)
- [M365 Restore Runbook](../../runbooks/M365_RESTORE.md)

---

**Next Steps:** Execute Phase 1: Assessment & Preparation



