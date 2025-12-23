# Bulletproof Backups: B2 Mirror & Restic Restore Runbook

> **Classification:** P0 / Mission-Critical
> **Owner:** PHC Infrastructure
> **Last Updated:** 2025-12-18

This runbook covers the complete backup and restore procedures for the PHC infrastructure, using Backblaze B2 for offsite storage.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Verifying Backup Status](#verifying-backup-status)
3. [Restore: B2 Mirror (Single File)](#restore-b2-mirror-single-file)
4. [Restore: B2 Mirror (Full Disaster Recovery)](#restore-b2-mirror-full-disaster-recovery)
5. [Restore: Restic Snapshots (Selective)](#restore-restic-snapshots-selective)
6. [Restore: Restic Snapshots (Full)](#restore-restic-snapshots-full)
7. [Bare Metal Rebuild](#bare-metal-rebuild)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Backup Components

| Component | Source | Destination | Schedule | Purpose |
|-----------|--------|-------------|----------|---------|
| **Space Mirror** | `/space` | `b2:miket-space-mirror` | Daily 4:00 AM | 1:1 mirror of SoR |
| **Flux Backup** | `/flux` | `b2:miket-backups-restic:flux` | Daily 5:00 AM | Versioned snapshots |
| **Restic Check** | N/A | N/A | Daily 6:00 AM | Integrity verification |
| **Restore Test** | B2 | Temp | Weekly Sat 7:00 AM | Automated drill |
| **Nextcloud DB** | PostgreSQL | `/space/_services/nextcloud/db-snapshots` | Daily 2:00 AM | Database dump |

### Storage Hierarchy

```
/space (SoR - Source of Record)
├── mike/                    # User data
├── projects/               # Graduated project archives
├── media/                  # Photos, video
├── datasets/               # ML datasets
├── archives/               # Deep cold storage
├── _services/
│   └── nextcloud/
│       ├── db-snapshots/   # PostgreSQL dumps (included in mirror)
│       └── config/         # Config backups
└── _ops/
    ├── data-estate/
    │   └── markers/        # Status markers (JSON)
    ├── logs/
    │   └── data-lifecycle/ # Backup logs
    └── backups/
        └── restore-tests/  # Automated restore drill results

/flux (Active workspace - backed up via restic)
├── active/                 # Current projects
├── scratch/                # Ephemeral work
└── models/                 # ML models
```

### Secrets Flow

```
Azure Key Vault (kv-miket-ops)
       │
       ▼ (secrets-sync.yml)
/etc/miket/storage-credentials.env (0600)
       │
       ▼ (systemd EnvironmentFile)
Backup Services (space-mirror, flux-backup, etc.)
```

**Required AKV secrets:**
- `b2-space-mirror-id` / `b2-space-mirror-key` - Rclone mirror credentials
- `b2-restic-id` / `b2-restic-key` - Restic B2 credentials
- `restic-password` - Restic repository encryption key

---

## Verifying Backup Status

### Quick Status Check

```bash
# On akira (space-mirror host):
cat /space/_ops/data-estate/markers/b2_mirror.json | jq .

# On motoko (flux-backup host):
cat /space/_ops/data-estate/markers/restic_cloud.json | jq .
cat /space/_ops/data-estate/markers/restic_check.json | jq .
cat /space/_ops/data-estate/markers/restore_test.json | jq .
```

### Timer Status

```bash
# Check all backup timers
systemctl list-timers 'space-mirror*' 'flux-backup*' 'restic-check*' 'restore-test*' --all

# Check specific timer
systemctl status space-mirror.timer
systemctl status flux-backup.timer
```

### Recent Run Status

```bash
# Space mirror (akira)
journalctl -u space-mirror.service -n 50 --no-pager

# Flux backup (motoko)
journalctl -u flux-backup.service -n 50 --no-pager

# Check for failures
cat /var/log/systemd-failures.log | tail -50
cat /space/_ops/logs/data-lifecycle/failures.log | tail -50
```

### Last Failure Check

```bash
# Check if any recent failures
cat /space/_ops/data-estate/markers/last_failure.json 2>/dev/null | jq . || echo "No recent failures"
```

### Verify B2 Bucket Contents

```bash
# Load credentials
source /etc/miket/storage-credentials.env
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

# List B2 mirror bucket
rclone ls :b2:miket-space-mirror --max-depth 1

# Check restic snapshots
restic -r b2:miket-backups-restic:flux snapshots
```

---

## Restore: B2 Mirror (Single File)

Use this procedure to restore a specific file or directory from the B2 mirror.

### Prerequisites

```bash
# Load credentials
source /etc/miket/storage-credentials.env
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"
```

### Restore Single File

```bash
# Example: Restore /space/mike/documents/important.pdf
rclone copy :b2:miket-space-mirror/mike/documents/important.pdf /tmp/restored/

# Verify
ls -la /tmp/restored/
```

### Restore Directory

```bash
# Example: Restore /space/mike/photos/2024/
rclone copy :b2:miket-space-mirror/mike/photos/2024/ /tmp/restored/photos/

# With progress
rclone copy :b2:miket-space-mirror/mike/photos/2024/ /tmp/restored/photos/ --progress
```

### Compare Before Overwriting

```bash
# Check differences before restoring in-place
rclone check :b2:miket-space-mirror/mike/documents/ /space/mike/documents/ --combined -

# Sync back (destructive - use with caution)
rclone sync :b2:miket-space-mirror/mike/documents/ /space/mike/documents/ --dry-run
```

---

## Restore: B2 Mirror (Full Disaster Recovery)

Use this procedure when `/space` has been lost or corrupted and needs full reconstruction.

### Prerequisites

1. New storage mounted at `/space` with sufficient capacity (18TB+)
2. Network connectivity to Backblaze B2
3. Credentials synced from AKV

### Procedure

```bash
# 1. Load credentials
source /etc/miket/storage-credentials.env
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

# 2. Create directory structure
mkdir -p /space

# 3. Restore full mirror (this will take hours)
rclone sync :b2:miket-space-mirror /space \
    --progress \
    --transfers 16 \
    --checkers 16 \
    --log-file=/tmp/restore-$(date +%Y%m%d).log \
    --log-level INFO

# 4. Verify file counts
rclone check :b2:miket-space-mirror /space --one-way

# 5. Restore permissions if needed
chown -R mdt:mdt /space/mike
chown -R mdt:mdt /space/projects
```

### Estimated Times

| Data Size | Estimated Time (100Mbps) |
|-----------|-------------------------|
| 1 TB | ~22 hours |
| 5 TB | ~4.5 days |
| 10 TB | ~9 days |

**Tip:** Use a high-bandwidth connection and increase `--transfers` for faster restores.

---

## Restore: Restic Snapshots (Selective)

Use restic when you need point-in-time recovery or to restore specific versions.

### Prerequisites

```bash
# Load credentials
source /etc/miket/storage-credentials.env
export RESTIC_REPOSITORY="b2:miket-backups-restic:flux"
export RESTIC_PASSWORD  # Already set from env file
export B2_ACCOUNT_ID
export B2_ACCOUNT_KEY
```

### List Available Snapshots

```bash
restic snapshots

# Filter by host
restic snapshots --host motoko

# Show snapshot details
restic snapshots --json | jq '.[] | {id: .short_id, time: .time, paths: .paths}'
```

### Browse Snapshot Contents

```bash
# List files in a snapshot
restic ls latest

# List specific path in snapshot
restic ls latest /flux/active/

# Find files matching pattern
restic find "*.py" --snapshot latest
```

### Restore Specific Files

```bash
# Restore single file to temp directory
restic restore latest --target /tmp/restore --include "/flux/active/project/file.py"

# Restore directory
restic restore latest --target /tmp/restore --include "/flux/active/project/"
```

### Restore Specific Snapshot

```bash
# Use snapshot ID (from `restic snapshots`)
restic restore abc123 --target /tmp/restore --include "/flux/active/"
```

---

## Restore: Restic Snapshots (Full)

Use this for complete `/flux` reconstruction.

### Procedure

```bash
# 1. Load credentials
source /etc/miket/storage-credentials.env
export RESTIC_REPOSITORY="b2:miket-backups-restic:flux"

# 2. List snapshots and pick one
restic snapshots

# 3. Restore full snapshot to /flux
# WARNING: This overwrites existing /flux contents!
restic restore latest --target /

# Or restore to a different location first
restic restore latest --target /tmp/flux-restore
mv /flux /flux.old
mv /tmp/flux-restore/flux /flux
```

### Verify Restoration

```bash
# Compare snapshot with restored data
restic diff latest:/flux /flux
```

---

## Bare Metal Rebuild

Complete reconstruction of a PHC host from scratch using only B2 backups and AKV.

### Phase 0: Base OS Installation

1. Install Fedora (latest stable) with standard partitioning
2. Create `mdt` user with sudo access
3. Configure network with static IP or DHCP reservation
4. Join Tailscale mesh: `sudo tailscale up --authkey=<from-AKV>`

### Phase 1: Bootstrap Ansible

```bash
# On motoko (control node):
cd ~/dev/miket-infra-devices

# Sync secrets from AKV
ansible-playbook -i ansible/inventory/hosts.yml \
    ansible/playbooks/secrets-sync.yml \
    --limit <target-host>
```

### Phase 2: Deploy Base Infrastructure

```bash
# Deploy baseline tools
ansible-playbook -i ansible/inventory/hosts.yml \
    ansible/playbooks/common/dev-tools.yml \
    --limit <target-host>

# Deploy data lifecycle (backup services)
ansible-playbook -i ansible/inventory/hosts.yml \
    ansible/playbooks/akira/deploy-data-lifecycle.yml \
    --limit akira
```

### Phase 3: Restore Data

```bash
# SSH to target host
ssh <target-host>

# Load credentials
source /etc/miket/storage-credentials.env
export RCLONE_B2_ACCOUNT="${B2_APPLICATION_KEY_ID}"
export RCLONE_B2_KEY="${B2_APPLICATION_KEY}"

# Restore /space from B2 mirror
rclone sync :b2:miket-space-mirror /space \
    --progress \
    --transfers 16

# Restore /flux from restic
export RESTIC_REPOSITORY="b2:miket-backups-restic:flux"
restic restore latest --target /
```

### Phase 4: Restart Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Restart backup timers
sudo systemctl restart space-mirror.timer
sudo systemctl restart flux-backup.timer

# Verify
systemctl list-timers --all | grep -E 'space-mirror|flux-backup'
```

---

## Troubleshooting

### Backup Job Failed

1. Check failure log:
   ```bash
   cat /space/_ops/data-estate/markers/last_failure.json | jq .
   journalctl -u <unit-name> -n 100 --no-pager
   ```

2. Common causes:
   - Network connectivity (check `host api.backblazeb2.com`)
   - Credential expiration (re-run `secrets-sync.yml`)
   - Disk space (check `df -h /space`)

3. Manual retry:
   ```bash
   sudo systemctl start space-mirror.service
   journalctl -fu space-mirror.service
   ```

### Restic Check Failed

A failed restic check indicates potential repository corruption.

```bash
# View detailed error
journalctl -u restic-check.service -n 200

# Try rebuilding index
restic -r b2:miket-backups-restic:flux rebuild-index

# If still failing, contact support - data may need recovery
```

### Restore Test Failed

```bash
# Check restore test results
ls -la /space/_ops/backups/restore-tests/
cat /space/_ops/backups/restore-tests/*.json | jq .

# Check logs
journalctl -u restore-test.service -n 100
```

### Credentials Not Found

```bash
# Verify env file exists and is populated
sudo cat /etc/miket/storage-credentials.env

# Re-sync from AKV
cd ~/dev/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
    ansible/playbooks/secrets-sync.yml \
    --limit $(hostname)
```

### Timer Not Running

```bash
# Check timer status
systemctl status space-mirror.timer

# Re-enable if disabled
sudo systemctl enable --now space-mirror.timer

# Force immediate run
sudo systemctl start space-mirror.service
```

---

## Emergency Contacts

- **Azure Key Vault:** kv-miket-ops (Azure Portal)
- **Backblaze B2 Console:** https://secure.backblaze.com/b2_buckets.htm
- **Infrastructure Repo:** miket-infra-devices (GitHub)

---

## Appendix: Marker File Reference

### b2_mirror.json

```json
{
  "job": "b2_mirror",
  "host": "akira",
  "started_at": "2025-12-18T04:00:00+00:00",
  "completed_at": "2025-12-18T05:23:15+00:00",
  "duration_seconds": 4995,
  "source": "/space",
  "destination": ":b2:miket-space-mirror",
  "status": "success",
  "message": "Mirror sync completed successfully",
  "files_transferred": 1234,
  "bytes_transferred": 5678901234
}
```

### restic_cloud.json

```json
{
  "job": "restic_cloud",
  "host": "motoko",
  "timestamp": "2025-12-18T05:15:00+00:00",
  "source": "/flux",
  "repo": "b2:miket-backups-restic:flux",
  "status": "success",
  "message": "Backup completed successfully",
  "snapshot_id": "abc123de"
}
```

### restore_test.json

```json
{
  "job": "restore_test",
  "host": "akira",
  "started_at": "2025-12-14T07:00:00+00:00",
  "completed_at": "2025-12-14T07:05:30+00:00",
  "duration_seconds": 330,
  "status": "success",
  "message": "All restore tests passed",
  "tests": {
    "b2_mirror": "PASS",
    "restic_snapshot": "PASS"
  }
}
```
