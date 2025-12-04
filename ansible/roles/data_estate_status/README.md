# Data Estate Status Role

Deploys the Data Estate Status Collector to monitor backup freshness, B2 mirror gaps, M365 ingestion, and unknown cloud remotes.

## Purpose

This role answers the critical question: "If the house burns down, what exactly is safe in the cloud, and how do I *know*?"

It deploys a collector script that runs every 6 hours and generates:
- **JSON output:** `/space/_ops/data-estate/status.json`
- **Markdown output:** `/space/_ops/nextcloud/dashboard/data-estate-status.md`

The Markdown output is designed to be displayed in Nextcloud's Welcome widget.

## Architecture

### Marker-Based Status Detection

The collector uses a **marker file system** for reliable status detection:

1. **Backup jobs write markers on success** - Each backup script (restic, space-mirror, Nextcloud DB, M365) writes a JSON marker file to `/space/_ops/data-estate/markers/` on successful completion.

2. **Collector reads markers first** - The collector prefers marker timestamps over journal parsing or direct repository queries.

3. **Fallback chain** - If markers are missing: marker → systemd journal → direct query (restic) → directory mtime

### Marker Files

| Job | Marker File | Written By |
|-----|-------------|------------|
| Restic Cloud | `restic_cloud.json` | `flux-backup.sh` |
| Restic Local | `restic_local.json` | `flux-local-snap.sh` |
| B2 Mirror | `b2_mirror.json` | `space-mirror.sh` |
| Nextcloud DB | `nextcloud_db.json` | `nextcloud-db-backup.sh` |
| M365 Ingest | `m365_ingest.json` | `sync-m365.sh` |

### Marker Schema

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

## Requirements

### Dependencies

- **data-lifecycle role:** Provides restic, rclone, backup services, and failure-notify template
- **secrets_sync role:** Provides `/etc/miket/storage-credentials.env`
- **nextcloud_server role:** Provides M365 sync and DB backup services

### Required Tools (installed by this role)

- `jq` - JSON parsing
- `bc` - Floating point calculations

### Required Services (from other roles)

- `space-mirror.service` - B2 mirror sync
- `flux-backup.service` - Restic cloud backup
- `flux-local.service` - Restic local snapshots
- `nextcloud-m365-sync.service` - M365 ingestion
- `nextcloud-db-backup.service` - Database dumps
- `failure-notify@.service` - OnFailure notification target

## Role Variables

### Feature Enablement

```yaml
# Enable/disable specific checks
# When disabled, checks report NOT_CONFIGURED instead of WARNING/CRITICAL
data_estate_restic_enabled: false
data_estate_nextcloud_db_enabled: false
data_estate_m365_enabled: true
data_estate_space_mirror_enabled: true
```

### SLO Thresholds (from DATA_ESTATE_SPEC)

```yaml
# Restic backups - 24h warning, 48h critical
data_estate_slo_restic_snapshot_max_age_hours: 48
data_estate_slo_restic_snapshot_warning_age_hours: 24

# Nextcloud DB - 24h warning, 48h critical
data_estate_slo_nextcloud_db_dump_max_age_hours: 48
data_estate_slo_nextcloud_db_dump_warning_age_hours: 24

# M365 ingestion - 6h warning, 24h critical
data_estate_slo_m365_ingestion_max_age_hours: 24
data_estate_slo_m365_ingestion_warning_age_hours: 6

# Space mirror - 24h warning, 48h critical
data_estate_slo_space_mirror_max_age_hours: 48
data_estate_slo_space_mirror_warning_age_hours: 24

# Mirror gap - 5% warning, 15% critical
data_estate_slo_space_mirror_max_gap_percent: 15
data_estate_slo_space_mirror_warning_gap_percent: 5
```

### Approved Cloud Remotes

```yaml
data_estate_approved_remotes:
  - name: b2-space-mirror
    type: b2
    bucket: miket-space-mirror
    purpose: "1:1 mirror of /space SoR"
  - name: b2-restic
    type: b2
    bucket: miket-backups-restic
    purpose: "Restic backup repository for /flux"
  - name: onedrive-business
    type: onedrive
    purpose: "M365 one-way ingestion source"
```

### Paths

```yaml
data_estate_config_dir: /etc/miket-infra/data-estate
data_estate_json_output_dir: /space/_ops/data-estate
data_estate_markdown_output_dir: /space/_ops/nextcloud/dashboard
data_estate_markers_dir: /space/_ops/data-estate/markers
data_estate_script_path: /usr/local/bin/data-estate-status.sh
data_estate_credentials_file: /etc/miket/storage-credentials.env
```

## Onboarding a New Host

To add Data Estate monitoring to a new host:

### 1. Define Host Variables

Create/update `host_vars/<hostname>.yml`:

```yaml
# Host role: nextcloud_server, storage_server, or workstation
data_estate_role: "storage_server"

# Enable checks based on what's deployed on this host
data_estate_restic_enabled: true      # If data-lifecycle role deployed
data_estate_nextcloud_db_enabled: false  # Only on Nextcloud host
data_estate_m365_enabled: false          # Only on M365 sync host
data_estate_space_mirror_enabled: true   # If space-mirror deployed

# Override thresholds if needed (inherit from role defaults otherwise)
# data_estate_slo_restic_snapshot_max_age_hours: 48
```

### 2. Deploy Prerequisites

```bash
# Ensure data-lifecycle role is deployed (for restic, rclone)
ansible-playbook -i inventory/hosts.yml playbooks/deploy-data-lifecycle.yml --limit <hostname>

# Deploy secrets
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit <hostname>
```

### 3. Deploy the Collector

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-data-estate-status.yml --limit <hostname>
```

### 4. Verify Deployment

```bash
# Check timer is running
systemctl status data-estate-status.timer

# Run manually
sudo systemctl start data-estate-status.service

# Check output
cat /space/_ops/data-estate/status.json
```

## What Gets Deployed

| Component | Path |
|-----------|------|
| Collector script | `/usr/local/bin/data-estate-status.sh` |
| Systemd service | `/etc/systemd/system/data-estate-status.service` |
| Systemd timer | `/etc/systemd/system/data-estate-status.timer` |
| Config (data estate) | `/etc/miket-infra/data-estate/data_estate.yml` |
| Config (approved remotes) | `/etc/miket-infra/data-estate/approved_remotes.yml` |
| JSON output | `/space/_ops/data-estate/status.json` |
| Markdown output | `/space/_ops/nextcloud/dashboard/data-estate-status.md` |

## Status Vocabulary

| Status | Meaning | Affects Overall? |
|--------|---------|------------------|
| `OK` | Within SLO thresholds | Yes (positive) |
| `WARNING` | Approaching threshold | Yes (degrades) |
| `CRITICAL` | Threshold exceeded | Yes (degrades) |
| `ERROR` | Check failed to run | Yes (degrades) |
| `NOT_CONFIGURED` | Feature disabled | No |
| `SUSPICIOUS` | Unexpected state | Yes (degrades to WARNING) |

### SUSPICIOUS State

The `SUSPICIOUS` status indicates something unexpected that warrants investigation:

- **B2 mirror larger than local:** Remote has more data than `/space` - could indicate stale B2 data, wrong bucket, or deleted local files
- **Unknown rclone remotes:** Remotes configured that aren't in the approved list

## Checks Performed

| Check | Description | OK | Warning | Critical |
|-------|-------------|----|---------| ---------|
| `restic_cloud_age` | Age of latest B2 restic snapshot | ≤ 24h | > 24h | > 48h |
| `restic_local_age` | Age of latest local restic snapshot | ≤ 24h | > 24h | > 48h |
| `space_mirror_age` | Time since last B2 mirror sync | ≤ 24h | > 24h | > 48h |
| `space_mirror_gap` | Size difference (local vs B2) | ≤ 5% | 5-15% | > 15% |
| `nextcloud_db_age` | Age of latest database dump | ≤ 24h | > 24h | > 48h |
| `m365_ingestion_age` | Time since last M365 sync | ≤ 6h | > 6h | > 24h |
| `unknown_remotes` | Unapproved rclone remotes | 0 | - | > 0 |

## Troubleshooting

### Marker Files Not Being Written

```bash
# Check if backup jobs are running
systemctl status flux-backup.timer space-mirror.timer

# Check marker directory permissions
ls -la /space/_ops/data-estate/markers/

# Check backup script logs
journalctl -u flux-backup.service -n 50
```

### Missing Credentials

```bash
# Deploy credentials
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko

# Verify
cat /etc/miket/storage-credentials.env
```

### Unknown Remotes Detected

```bash
# List all remotes
rclone listremotes

# Remove unauthorized remote
rclone config delete <remote-name>

# Or add to approved list in host_vars
```

### OnFailure Not Triggering

```bash
# Verify failure-notify service exists
systemctl cat failure-notify@.service

# Check for OnFailure= in service files
grep -r "OnFailure" /etc/systemd/system/
```

### Service Logs

```bash
# Collector logs
journalctl -u data-estate-status.service -n 100

# Failure notification logs
journalctl -u failure-notify@*.service -n 50
```

## License

Copyright (c) 2025 MikeT LLC. All rights reserved.
