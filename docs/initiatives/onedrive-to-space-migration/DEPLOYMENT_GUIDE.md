---
document_title: "OneDrive to /space Migration Deployment Guide"
author: "Codex-CA-001"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/onedrive-to-space-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# OneDrive to /space Migration Deployment Guide

**Status:** Published  
**Target Audience:** Infrastructure operators executing the migration  
**Prerequisites:** Rclone configured, Ansible access to motoko, sufficient disk space

---

## Pre-Migration Checklist

### 1. Verify Prerequisites

```bash
# Check disk space on motoko
ssh mdt@motoko "df -h /space"

# Verify Rclone remotes
ssh mdt@motoko "rclone listremotes"

# Expected output should include:
# m365-mike:
# m365-publish:

# Test OneDrive connectivity
ssh mdt@motoko "rclone lsd m365-mike:"

# Verify existing hoover backups
ssh mdt@motoko "ls -la /space/journal/m365/"
```

### 2. Inventory OneDrive Content

```bash
# List all accounts (manual step - update script with actual accounts)
ACCOUNTS=("mike" "other-user")

for ACCOUNT in "${ACCOUNTS[@]}"; do
    echo "=== Inventory for $ACCOUNT ==="
    ssh mdt@motoko "rclone size m365-${ACCOUNT}: --json" | jq '.bytes, .count'
done
```

### 3. Calculate Required Space

```bash
# Sum total size needed
# Add 20% buffer for safety
# Verify /space has sufficient capacity
```

---

## Deployment Steps

### Step 1: Deploy Migration Script

```bash
# From miket-infra-devices repository
cd /Users/miket/dev/miket-infra-devices

# Deploy script to motoko
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --tags deploy-script \
    --limit motoko
```

### Step 2: Configure Migration Parameters

Edit `/etc/miket/onedrive-migration.conf` on motoko:

```ini
[migration]
# Account to migrate
account=mike

# Destination directory
dest=/space/mike

# Conflict resolution: rename, skip, or overwrite
conflict_resolution=rename

# Parallel transfers
transfers=8

# Dry run mode (set to false for production)
dry_run=false
```

### Step 3: Execute Dry Run

```bash
# SSH to motoko
ssh mdt@motoko

# Run dry run
sudo /usr/local/bin/m365-migrate-to-space.sh \
    --account mike \
    --dest /space/mike \
    --dry-run \
    --verbose

# Review output and logs
sudo tail -f /var/log/m365-migrate-mike.log
```

### Step 4: Execute Production Migration

```bash
# After dry run validation, execute production migration
sudo /usr/local/bin/m365-migrate-to-space.sh \
    --account mike \
    --dest /space/mike \
    --transfers 8 \
    --verbose

# Monitor progress
sudo tail -f /var/log/m365-migrate-mike.log

# Check progress in another terminal
watch -n 30 'sudo du -sh /space/mike'
```

### Step 5: Validate Migration

```bash
# Compare file counts
SOURCE_COUNT=$(rclone size m365-mike: --json | jq '.count')
DEST_COUNT=$(find /space/mike -type f | wc -l)
echo "Source: $SOURCE_COUNT files"
echo "Destination: $DEST_COUNT files"

# Compare total size
SOURCE_SIZE=$(rclone size m365-mike: --json | jq '.bytes')
DEST_SIZE=$(du -sb /space/mike | cut -f1)
echo "Source: $SOURCE_SIZE bytes"
echo "Destination: $DEST_SIZE bytes"

# Verify checksums for critical files (sample)
# This is a manual step - select critical files to verify
```

### Step 6: Update Workflows

After successful migration:

```bash
# Update m365-publish.sh to reflect new architecture
# (May need to disable or modify for new sync patterns)

# Verify m365-hoover.sh still works with new structure
sudo /usr/local/bin/m365-hoover.sh mike
```

---

## Ansible Playbook Usage

### Full Migration (All Accounts)

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_accounts=['mike','other-user']"
```

### Single Account Migration

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike"
```

### Dry Run Mode

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "migration_account=mike dry_run=true"
```

---

## Monitoring & Troubleshooting

### Monitor Migration Progress

```bash
# Watch log file
sudo tail -f /var/log/m365-migrate-<account>.log

# Check disk usage
watch -n 60 'df -h /space'

# Check transfer rate
sudo iotop -o

# Check Rclone stats
sudo rclone rc core/stats
```

### Common Issues

#### Issue: Authentication Failure

**Symptoms:** `rclone: failed to list: 401 Unauthorized`

**Resolution:**
```bash
# Re-authenticate Rclone remote
rclone config reconnect m365-mike:
# Follow prompts to re-authenticate
```

#### Issue: Disk Space Full

**Symptoms:** `rclone: failed to copy: no space left on device`

**Resolution:**
```bash
# Check disk usage
df -h /space

# Free up space or expand partition
# Resume migration after space available
sudo /usr/local/bin/m365-migrate-to-space.sh \
    --account mike \
    --resume
```

#### Issue: Network Timeout

**Symptoms:** `rclone: failed to copy: context deadline exceeded`

**Resolution:**
```bash
# Migration script automatically retries
# Check network connectivity
ping 8.8.8.8

# Resume migration
sudo /usr/local/bin/m365-migrate-to-space.sh \
    --account mike \
    --resume
```

---

## Post-Migration Tasks

1. **Verify B2 Backup**
   ```bash
   # Wait for next nightly space-mirror run
   # Or trigger manually
   sudo systemctl start space-mirror.service
   ```

2. **Update Documentation**
   - Update file system architecture docs
   - Document new sync patterns
   - Update runbooks

3. **Archive OneDrive**
   - Keep OneDrive as read-only backup for 90 days
   - Document archive location
   - Schedule cleanup

---

## Rollback Procedure

If migration fails or issues discovered:

```bash
# Stop migration
sudo pkill -f m365-migrate-to-space.sh

# Verify OneDrive content intact
rclone lsd m365-mike:

# Restore from hoover backup if needed
# (See M365_RESTORE.md runbook)

# Document issues
# Fix and retry migration
```

---

## Success Validation

After migration completes:

- [ ] All files migrated (count matches)
- [ ] Total size matches (within 1% tolerance)
- [ ] Critical files verified (checksums)
- [ ] Directory structure correct
- [ ] Samba shares accessible
- [ ] B2 backup includes migrated content
- [ ] Logs reviewed for errors
- [ ] Documentation updated

---

**Related Documentation:**
- [Migration Plan](./MIGRATION_PLAN.md)
- [Rollback Procedures](./ROLLBACK_PROCEDURES.md)


