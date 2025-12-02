# Data Estate Status Role

Deploys the Data Estate Status Collector on motoko to monitor backup freshness, B2 mirror gaps, M365 ingestion, and unknown cloud remotes.

## Purpose

This role answers the critical question: "If the house burns down, what exactly is safe in the cloud, and how do I *know*?"

It deploys a collector script that runs every 6 hours and generates:
- **JSON output:** `/space/_ops/data-estate/status.json`
- **Markdown output:** `/space/_services/nextcloud/dashboard/data-estate-status.md`

The Markdown output is designed to be displayed in Nextcloud's Welcome widget.

## Requirements

### Dependencies

- **data-lifecycle role:** Provides restic, rclone, and backup services
- **secrets_sync role:** Provides `/etc/miket/storage-credentials.env`
- **nextcloud_server role:** Provides M365 sync and DB backup services

### Required Tools (installed by this role)

- `jq` - JSON parsing
- `bc` - Floating point calculations
- `yq` - YAML parsing (Fedora/RHEL)

### Required Services (from other roles)

- `space-mirror.service` - B2 mirror sync
- `flux-backup.service` - Restic cloud backup
- `flux-local.service` - Restic local snapshots
- `nextcloud-m365-sync.service` - M365 ingestion
- `nextcloud-db-backup.service` - Database dumps

## Role Variables

### SLO Thresholds

```yaml
# Maximum age before CRITICAL status
data_estate_slo_space_mirror_max_age_hours: 24
data_estate_slo_space_mirror_max_gap_percent: 5.0
data_estate_slo_restic_snapshot_max_age_hours: 24
data_estate_slo_nextcloud_db_dump_max_age_hours: 24
data_estate_slo_m365_ingestion_max_age_hours: 24

# Warning thresholds (approaching CRITICAL)
data_estate_slo_space_mirror_warning_age_hours: 18
data_estate_slo_space_mirror_warning_gap_percent: 1.0
data_estate_slo_restic_snapshot_warning_age_hours: 18
data_estate_slo_nextcloud_db_dump_warning_age_hours: 18
data_estate_slo_m365_ingestion_warning_age_hours: 18
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
data_estate_markdown_output_dir: /space/_services/nextcloud/dashboard
data_estate_script_path: /usr/local/bin/data-estate-status.sh
data_estate_credentials_file: /etc/miket/storage-credentials.env
```

### Timer Configuration

```yaml
data_estate_timer_schedule: "*-*-* 0/6:00:00"  # Every 6 hours
data_estate_timer_accuracy: 5min
data_estate_timer_persistent: true
```

## Usage

### Standalone Playbook

```bash
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-estate-status.yml
```

### Include in Other Playbooks

```yaml
- name: Deploy motoko services
  hosts: motoko
  roles:
    - role: data-lifecycle
    - role: nextcloud_server
    - role: data_estate_status
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
| Markdown output | `/space/_services/nextcloud/dashboard/data-estate-status.md` |

## Checks Performed

| Check | Description | Status Logic |
|-------|-------------|--------------|
| `restic_cloud_age` | Age of latest B2 restic snapshot | OK < 18h, WARNING < 24h, CRITICAL >= 24h |
| `restic_local_age` | Age of latest local restic snapshot | OK < 18h, WARNING < 24h, CRITICAL >= 24h |
| `space_mirror_age` | Time since last B2 mirror sync | OK < 18h, WARNING < 24h, CRITICAL >= 24h |
| `space_mirror_gap` | Size difference (local vs B2) | OK < 1%, WARNING < 5%, CRITICAL >= 5% |
| `nextcloud_db_age` | Age of latest database dump | OK < 18h, WARNING < 24h, CRITICAL >= 24h |
| `m365_ingestion_age` | Time since last M365 sync | OK < 18h, WARNING < 24h, CRITICAL >= 24h |
| `unknown_remotes` | Unapproved rclone remotes | OK = 0, CRITICAL > 0 |

## Post-Deployment Steps

### 1. Verify Timer is Running

```bash
systemctl status data-estate-status.timer
systemctl list-timers data-estate-status.timer
```

### 2. Run Collector Manually

```bash
sudo systemctl start data-estate-status.service
```

### 3. Check Output

```bash
cat /space/_services/nextcloud/dashboard/data-estate-status.md
jq . /space/_ops/data-estate/status.json
```

### 4. Configure Nextcloud Widget (Manual)

1. Log into Nextcloud as admin
2. Go to Dashboard
3. Click "Customize" or gear icon
4. Enable "Welcome" widget

## Troubleshooting

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

# Or add to approved list in defaults/main.yml
```

### Service Logs

```bash
journalctl -u data-estate-status.service -n 100
```

## License

Copyright (c) 2025 MikeT LLC. All rights reserved.

