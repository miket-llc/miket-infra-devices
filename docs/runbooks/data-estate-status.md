# Data Estate Status Collector Runbook

**Status:** ACTIVE  
**Target:** motoko (PHC storage server)  
**Owner:** Infrastructure Team

## Overview

The Data Estate Status Collector monitors the health of backup systems and cloud storage to ensure data survivability in disaster scenarios. It answers the critical question:

> "If the house burns down, what exactly is safe in the cloud, and how do I *know*?"

The collector runs every 6 hours and generates:
- **JSON output:** `/space/_ops/data-estate/status.json` (machine-readable)
- **Markdown output:** `/space/_services/nextcloud/dashboard/data-estate-status.md` (human-readable, displayed in Nextcloud)

## What Gets Monitored

| Check | Description | SLO Threshold |
|-------|-------------|---------------|
| Restic Cloud Snapshot | Age of latest `/flux` backup to B2 | < 24 hours |
| Restic Local Snapshot | Age of latest `/flux` snapshot to `/space/snapshots` | < 24 hours |
| Space Mirror Age | Time since last successful sync to B2 | < 24 hours |
| Space Mirror Gap | Size difference between `/space` and B2 mirror | < 5% |
| Nextcloud DB Dump | Age of latest PostgreSQL dump | < 24 hours |
| M365 Ingestion | Time since last OneDrive sync | < 24 hours |
| Unknown Remotes | Detection of unapproved rclone remotes | 0 unknown |

## Quick Commands

### Check Current Status

```bash
# View human-readable status
cat /space/_services/nextcloud/dashboard/data-estate-status.md

# View detailed JSON status
jq . /space/_ops/data-estate/status.json

# Check overall status only
jq -r '.overall_status' /space/_ops/data-estate/status.json
```

### Run Collector Manually

```bash
# Run immediately via systemd
sudo systemctl start data-estate-status.service

# Run directly (for debugging)
sudo /usr/local/bin/data-estate-status.sh

# View logs
journalctl -u data-estate-status.service -n 100
```

### Check Timer Status

```bash
# Timer status
systemctl status data-estate-status.timer

# Next scheduled run
systemctl list-timers data-estate-status.timer

# Timer history
journalctl -u data-estate-status.timer -n 20
```

## Interpreting Status

### Overall Status

- **OK:** All SLO thresholds met. Data estate is healthy.
- **WARNING:** Some thresholds approaching limits. Investigate soon.
- **CRITICAL:** One or more thresholds exceeded. Immediate action required.

### Status Indicators (Markdown)

- ✅ **OK:** Check passed, within SLO
- ⚠️ **WARNING:** Approaching threshold, needs attention
- ❗ **CRITICAL:** Threshold exceeded, immediate action required
- ❓ **UNKNOWN:** Unable to determine status (check dependencies)

## Troubleshooting

### "Missing B2/restic credentials"

**Cause:** The credentials file `/etc/miket/storage-credentials.env` is missing or incomplete.

**Fix:**
```bash
# Run secrets sync to deploy credentials
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko

# Verify credentials file exists
cat /etc/miket/storage-credentials.env
```

### "Unable to connect to restic repository"

**Cause:** B2 credentials invalid or network issue.

**Fix:**
```bash
# Test B2 connectivity
source /etc/miket/storage-credentials.env
restic -r b2:miket-backups-restic:flux snapshots --latest 1

# Check rclone B2 access
rclone lsd :b2:miket-backups-restic
```

### "No successful sync found in journal"

**Cause:** The backup service hasn't run successfully yet.

**Fix:**
```bash
# Check service status
systemctl status space-mirror.service
systemctl status flux-backup.service

# View service logs
journalctl -u space-mirror.service -n 50

# Trigger manual run
sudo systemctl start space-mirror.service
```

### "Unknown remote(s) detected"

**Cause:** rclone has remotes configured that aren't in the approved list.

**Investigation:**
```bash
# List all configured remotes
rclone listremotes

# View remote details
rclone config dump --json | jq .

# Check approved list
cat /etc/miket-infra/data-estate/approved_remotes.yml
```

**Resolution:**
1. If the remote is legitimate, add it to `approved_remotes` in the Ansible role defaults
2. If the remote is unauthorized, remove it: `rclone config delete <remote-name>`

### "Unable to determine local /space size"

**Cause:** `/space` mount point issue or permissions.

**Fix:**
```bash
# Check mount status
mount | grep /space
df -h /space

# If not mounted, check fstab and remount
cat /etc/fstab | grep space
sudo mount /space
```

## Nextcloud Dashboard Widget

### Initial Setup (Admin Required)

1. Log into Nextcloud as admin
2. Navigate to Dashboard (home page)
3. Click "Customize" or the gear icon
4. Enable the "Welcome" widget
5. The widget will display the data-estate-status.md file

### If Widget Not Showing

1. Verify Welcome app is installed:
   ```bash
   podman exec -u 33 nextcloud-app php occ app:list | grep welcome
   ```

2. Verify external storage is configured:
   ```bash
   podman exec -u 33 nextcloud-app php occ files_external:list
   ```

3. Check file permissions:
   ```bash
   ls -la /space/_services/nextcloud/dashboard/
   ```

## Configuration Files

| File | Purpose |
|------|---------|
| `/etc/miket-infra/data-estate/data_estate.yml` | SLO thresholds and data asset definitions |
| `/etc/miket-infra/data-estate/approved_remotes.yml` | Approved cloud remote registry |
| `/etc/miket/storage-credentials.env` | B2 and restic credentials |
| `/usr/local/bin/data-estate-status.sh` | Collector script |
| `/etc/systemd/system/data-estate-status.service` | Systemd service unit |
| `/etc/systemd/system/data-estate-status.timer` | Systemd timer unit |

## Deployment

### Initial Deployment

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-estate-status.yml
```

### Update Configuration

1. Modify variables in `ansible/roles/data_estate_status/defaults/main.yml`
2. Re-run the playbook:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-estate-status.yml
   ```

### Verify Deployment

```bash
# Check all components
systemctl status data-estate-status.timer
ls -la /usr/local/bin/data-estate-status.sh
ls -la /etc/miket-infra/data-estate/
ls -la /space/_ops/data-estate/
ls -la /space/_services/nextcloud/dashboard/
```

## Dependencies

The collector depends on:

1. **data-lifecycle role:** Provides restic, rclone, and backup services
2. **secrets_sync role:** Provides B2/restic credentials
3. **nextcloud_server role:** Provides M365 sync and DB backup services

If any dependency is missing, related checks will fail gracefully with WARNING or CRITICAL status.

## Disaster Recovery Context

This collector is part of the "house burns down" preparedness strategy:

- **System of Record (SoR):** `/space` contains all critical data
- **Cloud Copies:**
  - B2 `miket-space-mirror`: 1:1 mirror of `/space`
  - B2 `miket-backups-restic`: Versioned backups of `/flux`
  - M365: Source data ingested into `/space/mike/inbox/ms365`

If all local storage is lost, restoration path is:
1. Restore `/space` from B2 mirror (rclone sync)
2. Restore `/flux` from B2 restic repo (restic restore)
3. Re-run Ansible playbooks to rebuild services

The collector ensures these cloud copies stay fresh and complete.

## Related Documentation

- [Data Lifecycle Spec](../product/DATA_LIFECYCLE_SPEC.md)
- [Filesystem Architecture](../architecture/FILESYSTEM_ARCHITECTURE.md)
- [Secrets Management](../reference/secrets-management.md)
- [Backblaze Manual Trigger](../guides/backblaze-manual-trigger.md)

