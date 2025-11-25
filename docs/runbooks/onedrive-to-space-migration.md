---
document_title: "OneDrive to /space Migration Runbook"
author: "Codex-CA-001"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/onedrive-to-space-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# OneDrive to /space Migration Runbook

**Status:** Published  
**Purpose:** Operational guide for executing OneDrive to /space migration  
**Target:** motoko (Ubuntu 24.04.2 LTS)

---

## Quick Reference

### Prerequisites
- Rclone configured with M365 remote (`m365-<account>`)
- Sufficient disk space on `/space` partition
- SSH access to motoko as `mdt` user

### Quick Start

```bash
# Dry run
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike dry_run=true"

# Production migration
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike"
```

---

## Pre-Migration Checklist

### 1. Verify Prerequisites

```bash
# Check disk space
ssh mdt@motoko "df -h /space"

# Verify Rclone remotes
ssh mdt@motoko "rclone listremotes"

# Test connectivity
ssh mdt@motoko "rclone lsd m365-mike:"
```

### 2. Inventory OneDrive Content

```bash
# Calculate source size
ssh mdt@motoko "rclone size m365-mike: --json" | jq '.bytes, .count'

# Verify sufficient space (add 20% buffer)
```

### 3. Verify Existing Backups

```bash
# Check hoover backups exist
ssh mdt@motoko "ls -la /space/journal/m365/mike/"

# Verify B2 backup is current
ssh mdt@motoko "rclone lsd b2:miket-space-mirror/"
```

---

## Execution Steps

### Step 1: Deploy Migration Script

```bash
cd /Users/miket/dev/miket-infra-devices

ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --tags deploy-script \
    --extra-vars "migration_account=mike migration_dest=/space/mike"
```

### Step 2: Execute Dry Run

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike dry_run=true"
```

### Step 3: Review Dry Run Results

```bash
# Check log file
ssh mdt@motoko "sudo tail -100 /var/log/m365-migrate-mike.log"

# Verify no errors
ssh mdt@motoko "sudo grep -i error /var/log/m365-migrate-mike.log"
```

### Step 4: Execute Production Migration

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike migration_transfers=16"
```

### Step 5: Monitor Progress

```bash
# Watch log file
ssh mdt@motoko "sudo tail -f /var/log/m365-migrate-mike.log"

# Check disk usage
ssh mdt@motoko "watch -n 60 'df -h /space'"

# Check transfer rate
ssh mdt@motoko "sudo iotop -o"
```

### Step 6: Validate Migration

```bash
# Compare file counts
SOURCE_COUNT=$(ssh mdt@motoko "rclone size m365-mike: --json" | jq '.count')
DEST_COUNT=$(ssh mdt@motoko "find /space/mike -type f | wc -l")
echo "Source: $SOURCE_COUNT, Destination: $DEST_COUNT"

# Compare sizes
SOURCE_SIZE=$(ssh mdt@motoko "rclone size m365-mike: --json" | jq '.bytes')
DEST_SIZE=$(ssh mdt@motoko "du -sb /space/mike" | cut -f1)
echo "Source: $SOURCE_SIZE bytes, Destination: $DEST_SIZE bytes"
```

---

## Troubleshooting

### Issue: Authentication Failure

**Symptoms:** `rclone: failed to list: 401 Unauthorized`

**Resolution:**
```bash
ssh mdt@motoko
rclone config reconnect m365-mike:
# Follow prompts to re-authenticate
```

### Issue: Disk Space Full

**Symptoms:** `rclone: failed to copy: no space left on device`

**Resolution:**
```bash
# Free up space
ssh mdt@motoko "du -sh /space/* | sort -h"

# Resume migration after freeing space
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike"
```

### Issue: Network Timeout

**Symptoms:** `rclone: failed to copy: context deadline exceeded`

**Resolution:**
```bash
# Migration script automatically retries
# Check network connectivity
ssh mdt@motoko "ping -c 3 8.8.8.8"

# Resume migration
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike migration_dest=/space/mike"
```

### Issue: Migration Script Not Found

**Symptoms:** `ansible: command not found: /usr/local/bin/m365-migrate-to-space.sh`

**Resolution:**
```bash
# Deploy script manually
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --tags deploy-script
```

---

## Post-Migration Tasks

### 1. Verify B2 Backup

```bash
# Wait for next nightly space-mirror run
# Or trigger manually
ssh mdt@motoko "sudo systemctl start space-mirror.service"

# Verify backup
ssh mdt@motoko "rclone lsd b2:miket-space-mirror/mike/"
```

### 2. Update Workflows

```bash
# Review m365-publish.sh (may need updates)
ssh mdt@motoko "cat /usr/local/bin/m365-publish.sh"

# Verify m365-hoover.sh still works
ssh mdt@motoko "sudo /usr/local/bin/m365-hoover.sh mike"
```

### 3. Test Samba Access

```bash
# From Windows workstation
net use S: \\motoko\space

# From macOS
mount_smbfs //mdt@motoko/space /mnt/space

# Verify migrated content accessible
```

---

## Rollback Procedure

If migration fails:

```bash
# Stop migration
ssh mdt@motoko "sudo pkill -f m365-migrate-to-space.sh"

# Verify OneDrive intact
ssh mdt@motoko "rclone lsd m365-mike:"

# Restore from hoover backup if needed
# (See M365_RESTORE.md runbook)
```

---

## Success Criteria

- [ ] All files migrated (count matches within 1%)
- [ ] Total size matches (within 1% tolerance)
- [ ] Critical files verified (checksums)
- [ ] Directory structure correct
- [ ] Samba shares accessible
- [ ] B2 backup includes migrated content
- [ ] Logs reviewed for errors
- [ ] Documentation updated

---

## Related Documentation

- [Migration Plan](../initiatives/onedrive-to-space-migration/MIGRATION_PLAN.md)
- [Deployment Guide](../initiatives/onedrive-to-space-migration/DEPLOYMENT_GUIDE.md)
- [Rollback Procedures](../initiatives/onedrive-to-space-migration/ROLLBACK_PROCEDURES.md)
- [M365 Restore Runbook](./M365_RESTORE.md)


