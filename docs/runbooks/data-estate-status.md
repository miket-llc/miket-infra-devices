# Data Estate Status Collector Runbook

**Status:** ACTIVE  
**Target:** motoko (PHC storage server), extensible to other hosts  
**Owner:** Infrastructure Team

## Overview

The Data Estate Status Collector monitors the health of backup systems and cloud storage to ensure data survivability in disaster scenarios. It answers the critical question:

> "If the house burns down, what exactly is safe in the cloud, and how do I *know*?"

The collector runs every 6 hours and generates:
- **JSON output:** `/space/_ops/data-estate/status.json` (machine-readable)
- **Markdown output:** `/space/_ops/nextcloud/dashboard/data-estate-status.md` (human-readable, displayed in Nextcloud)

## Architecture: Marker-Based Status Detection

The collector uses a **marker file system** for reliable and fast status detection:

### How It Works

1. **Backup jobs write markers on success** - Each job (restic, space-mirror, Nextcloud DB, M365) writes a JSON marker file to `/space/_ops/data-estate/markers/` upon successful completion.

2. **Collector reads markers first** - The collector prefers marker file timestamps over journal parsing or direct repository queries.

3. **Fallback chain** - If markers are missing or corrupted:
   - Marker file → systemd journal → direct query (restic/rclone) → directory mtime

### Marker Files

| Job | Marker File | Written By |
|-----|-------------|------------|
| Restic Cloud | `restic_cloud.json` | `flux-backup.sh` |
| Restic Local | `restic_local.json` | `flux-local-snap.sh` |
| B2 Mirror | `b2_mirror.json` | `space-mirror.sh` |
| Nextcloud DB | `nextcloud_db.json` | `nextcloud-db-backup.sh` |
| M365 Ingest | `m365_ingest.json` | `sync-m365.sh` |

### Marker File Schema

```json
{
  "job": "restic_cloud",
  "host": "motoko",
  "timestamp": "2025-12-02T18:30:00+00:00",
  "source": "/flux",
  "repo": "b2:miket-backups-restic:flux",
  "status": "success",
  "message": "Backup completed successfully",
  "snapshot_id": "abc123..."
}
```

**Key behavior:**
- Markers are written **only on success** (atomic write via temp file + mv)
- Failed jobs **do not** overwrite markers - preserving last success timestamp
- Corrupted markers fall back to journal/direct query

## What Gets Monitored

| Check | Description | OK | Warning | Critical |
|-------|-------------|----|---------| ---------|
| Restic Cloud Snapshot | Age of latest `/flux` backup to B2 | ≤ 24h | > 24h | > 48h |
| Restic Local Snapshot | Age of latest `/flux` snapshot to `/space/snapshots` | ≤ 24h | > 24h | > 48h |
| Space Mirror Age | Time since last successful sync to B2 | ≤ 24h | > 24h | > 48h |
| Space Mirror Gap | Size difference between `/space` and B2 mirror | ≤ 5% | 5-15% | > 15% |
| Nextcloud DB Dump | Age of latest PostgreSQL dump | ≤ 24h | > 24h | > 48h |
| M365 Ingestion | Time since last OneDrive sync | ≤ 6h | > 6h | > 24h |
| Unknown Remotes | Detection of unapproved rclone remotes | 0 | - | > 0 |

## Status Vocabulary

| Status | Meaning | Affects Overall? |
|--------|---------|------------------|
| `OK` | Within SLO thresholds | Yes (positive) |
| `WARNING` | Approaching threshold | Yes (degrades) |
| `CRITICAL` | Threshold exceeded | Yes (degrades) |
| `ERROR` | Check failed to run | Yes (degrades) |
| `NOT_CONFIGURED` | Feature disabled for this host | No |
| `SUSPICIOUS` | Unexpected state (investigate) | Yes (degrades to WARNING) |

### SUSPICIOUS State

The `SUSPICIOUS` status indicates something unexpected:
- **B2 mirror larger than local:** Remote has more data than `/space` - could indicate stale B2 data, wrong bucket, or deleted local files
- **Unknown rclone remotes:** Remotes configured that aren't in the approved list

## Quick Commands

### Check Current Status

```bash
# View human-readable status
cat /space/_ops/nextcloud/dashboard/data-estate-status.md

# View detailed JSON status
jq . /space/_ops/data-estate/status.json

# Check overall status only
jq -r '.overall_status' /space/_ops/data-estate/status.json

# List marker files
ls -la /space/_ops/data-estate/markers/

# View a specific marker
jq . /space/_ops/data-estate/markers/restic_cloud.json
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

### Run Backup Jobs Manually

```bash
# Run restic cloud backup
sudo systemctl start flux-backup.service

# Run restic local snapshot
sudo systemctl start flux-local.service

# Run space mirror
sudo systemctl start space-mirror.service

# Run Nextcloud DB backup
sudo systemctl start nextcloud-db-backup.service

# Run M365 sync
sudo systemctl start nextcloud-m365-sync.service

# Then verify markers were updated
ls -la /space/_ops/data-estate/markers/
```

## Troubleshooting

### Marker Files Not Being Written

**Symptoms:** Collector falls back to journal or shows old timestamps despite recent successful runs.

**Investigation:**
```bash
# Check marker directory exists and permissions
ls -la /space/_ops/data-estate/markers/

# Check backup job logs for marker writing
journalctl -u flux-backup.service -n 50 | grep -i marker

# Manually run backup job with verbose output
sudo /usr/local/bin/flux-backup.sh
```

**Fix:**
1. Ensure marker directory exists: `mkdir -p /space/_ops/data-estate/markers`
2. Check disk space on `/space`
3. Re-run the backup job

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

### "No successful sync found" (Despite Recent Runs)

**Cause:** Marker file not written (job failed before marker write, or marker path issue).

**Investigation:**
```bash
# Check if marker exists
ls -la /space/_ops/data-estate/markers/b2_mirror.json

# Check journal for recent runs
journalctl -u space-mirror.service --since "24 hours ago"

# Look for errors in job logs
cat /space/_ops/logs/data-lifecycle/space-mirror.log | tail -100
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
1. If the remote is legitimate, add it to `approved_remotes` in host_vars
2. If the remote is unauthorized, remove it: `rclone config delete <remote-name>`

### OnFailure Not Triggering

**Cause:** failure-notify@ service not deployed or misconfigured.

**Fix:**
```bash
# Verify failure-notify service exists
systemctl cat failure-notify@.service

# Check OnFailure is set in service files
grep -r "OnFailure" /etc/systemd/system/*.service

# Simulate a failure (carefully!)
systemctl start failure-notify@test.service
journalctl -u failure-notify@test.service
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
| `/space/_ops/data-estate/markers/*.json` | Success marker files from backup jobs |

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
   ls -la /space/_ops/nextcloud/dashboard/
   ```

## Deployment

### Initial Deployment

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-estate-status.yml
```

### Update Configuration

1. Modify variables in `ansible/host_vars/motoko.yml` (host-specific) or `ansible/roles/data_estate_status/defaults/main.yml` (defaults)
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
ls -la /space/_ops/data-estate/markers/
ls -la /space/_ops/nextcloud/dashboard/
```

## Dependencies

The collector depends on:

1. **data-lifecycle role:** Provides restic, rclone, backup services, and failure-notify template
2. **secrets_sync role:** Provides B2/restic credentials
3. **nextcloud_server role:** Provides M365 sync and DB backup services (if enabled)

If any dependency is missing, related checks will fail gracefully with ERROR or NOT_CONFIGURED status.

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
- [Role README](../../ansible/roles/data_estate_status/README.md)
