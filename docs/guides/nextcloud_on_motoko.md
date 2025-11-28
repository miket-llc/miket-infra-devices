---
document_title: "Nextcloud on Motoko Deployment Guide"
author: "Codex-CA-001"
last_updated: 2025-11-28
status: Published
related_initiatives:
  - initiatives/nextcloud-deployment
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# Nextcloud on Motoko

**Status:** Published  
**Purpose:** Operational guide for Nextcloud server on motoko  
**Target:** motoko (Ubuntu 24.04.2 LTS)

---

## Overview

Nextcloud runs on motoko as a **pure façade** over `/space`. This means:

- **All user content lives on `/space`** (System of Record)
- **Internal Nextcloud homes are empty** - no skeleton/welcome files
- **External storage mounts** expose existing `/space/mike` directories
- **Home sweeper** detects and quarantines any stray files in internal homes

Nextcloud provides:

- **File sync** across devices via Nextcloud desktop/mobile clients
- **External storage mounts** pointing to existing `/space/mike` directories
- **M365 ingestion** (one-way sync from OneDrive/SharePoint to `/space`)
- **Cloudflare Access** protection for external access

### Pure Façade Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PURE FAÇADE PRINCIPLE                        │
├─────────────────────────────────────────────────────────────────┤
│  Nextcloud ──────────►  Metadata & Caches ONLY                  │
│  Internal Home          /mnt/data/nextcloud/data/<user>/        │
│                         ├── files/        ← MUST BE EMPTY       │
│                         ├── cache/        ← OK (internal)       │
│                         └── uploads/      ← OK (transient)      │
│                                                                  │
│  User Content ───────►  /space/mike/<folder>                    │
│  (System of Record)     via External Storage mounts             │
└─────────────────────────────────────────────────────────────────┘
```

**Why?** Prevents data duplication, ensures `/space` remains the single source of truth, and simplifies backup/recovery by keeping Nextcloud as a stateless access layer.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         MOTOKO                                   │
├─────────────────────────────────────────────────────────────────┤
│  /flux/apps/nextcloud/     (runtime stack)                      │
│  ├── docker-compose.yml                                          │
│  ├── config/rclone-m365.conf                                    │
│  └── bin/                                                        │
│      ├── sync-m365.sh                                           │
│      └── nextcloud-db-backup.sh                                 │
│                                                                  │
│  /flux/runtime/secrets/nextcloud.env  (from AKV)                │
├─────────────────────────────────────────────────────────────────┤
│  /mnt/data/nextcloud/         (app data - internal NVMe)        │
│  ├── data/      (Nextcloud internal data)                       │
│  └── db/        (PostgreSQL data)                               │
│                                                                  │
│  /space/_services/nextcloud/  (backups - SoR)                   │
│  └── db-backups/ (nightly dumps)                                │
│                                                                  │
│  /space/mike/   (user files - external mounts)                  │
│  ├── work/      → NC: /work                                     │
│  ├── media/     → NC: /media                                    │
│  ├── finance/   → NC: /finance                                  │
│  ├── assets/    → NC: /assets                                   │
│  ├── camera/    → NC: /camera                                   │
│  ├── inbox/     → NC: /inbox                                    │
│  │   └── ms365/ → NC: /ms365                                    │
│  ├── dev/       ❌ NOT mounted (dev workloads)                  │
│  ├── code/      ❌ NOT mounted (git repos)                      │
│  └── art/       ❌ NOT mounted (creative projects)              │
│                                                                  │
│  /space/projects/** ❌ NEVER mounted                            │
└─────────────────────────────────────────────────────────────────┘
```

## Endpoints

| Type | URL | Protection |
|------|-----|------------|
| External | `https://nextcloud.miket.io` | Cloudflare Access (Entra IdP) |
| Internal | `http://nextcloud.motoko:8080` | Tailscale only |

Cloudflare Access App ID: `e49a8197-8500-4ef1-9fc3-410d77cf861a`

## Deployment

### Prerequisites

1. **Azure Key Vault secrets** (in `kv-miket-ops`):
   - `nextcloud-db-user`
   - `nextcloud-db-password`
   - `nextcloud-admin-user`
   - `nextcloud-admin-bootstrap-password`
   - `m365-nextcloud-client-id`
   - `m365-nextcloud-client-secret`
   - `nextcloud-redis-password`

2. **Sync secrets**:
   ```bash
   ansible-playbook playbooks/secrets-sync.yml --limit motoko
   ```

### Deploy Stack

```bash
cd ~/miket-infra-devices
ansible-playbook ansible/playbooks/motoko/deploy-nextcloud.yml --limit motoko
```

### Validate Deployment

```bash
# Check containers
docker ps | grep nextcloud

# Check service status
systemctl status nextcloud
systemctl status nextcloud-m365-sync.timer
systemctl status nextcloud-db-backup.timer

# Check Nextcloud status
curl http://localhost:8080/status.php | jq
```

## Operations

### Restart Stack

```bash
# Via systemd (preferred)
sudo systemctl restart nextcloud

# Via docker compose
cd /flux/apps/nextcloud
sudo docker compose restart
```

### Upgrade Nextcloud

```bash
# Update image tag in defaults/main.yml
# Re-run playbook
ansible-playbook ansible/playbooks/motoko/deploy-nextcloud.yml --limit motoko
```

### Maintenance Mode

```bash
# Enable
docker exec nextcloud-app php occ maintenance:mode --on

# Disable
docker exec nextcloud-app php occ maintenance:mode --off
```

### File Scan

```bash
# Scan all files
docker exec nextcloud-app php occ files:scan --all

# Scan specific user
docker exec nextcloud-app php occ files:scan mike
```

## Backup & Restore

### Backup (Automated)

- **DB dumps**: `/space/_services/nextcloud/db-backups/` (nightly at 02:00)
- **restic**: Included in space-mirror (covers `/space/_services/nextcloud/**`)

### Manual DB Backup

```bash
sudo /flux/apps/nextcloud/bin/nextcloud-db-backup.sh
```

### Restore from Backup

1. Stop containers:
   ```bash
   sudo systemctl stop nextcloud
   ```

2. Restore DB:
   ```bash
   # Decompress backup
   gunzip /space/_services/nextcloud/db-backups/nextcloud_db_YYYYMMDD_HHMMSS.sql.gz
   
   # Restore
   docker exec -i nextcloud-db psql -U nextcloud < /path/to/backup.sql
   ```

3. Restore files (if needed):
   ```bash
   restic restore latest --target /space/_services/nextcloud/data --path /space/_services/nextcloud/data
   ```

4. Restart:
   ```bash
   sudo systemctl start nextcloud
   ```

## Excluded Directories

The following directories are **NEVER** exposed to Nextcloud:

| Directory | Reason |
|-----------|--------|
| `/space/mike/dev` | Development environments, VMs |
| `/space/mike/code` | Git repos, node_modules |
| `/space/mike/art` | Large creative projects (DAW, video) |
| `/space/projects/**` | Shared project workloads |

These workloads should access `/space` directly via SMB mounts.

## Pure Façade Configuration

### Skeleton Files (Disabled)

New Nextcloud users do **NOT** receive:
- `Nextcloud Manual.pdf`
- Sample `Photos` folder
- Sample `Documents` folder
- Any welcome/README files

This is configured via:
```php
'skeletondirectory' => '',
```

The Ansible role automatically:
1. Sets `skeletondirectory` to empty string
2. Clears any existing skeleton directory contents
3. Removes skeleton files from existing user homes

### Home Sweeper

A daily job detects any files that accidentally end up in internal user homes:

```bash
# Check sweeper status
systemctl status nextcloud-home-sweeper.timer

# View sweeper logs
journalctl -u nextcloud-home-sweeper.service

# Manual run (alert-only mode)
/flux/apps/nextcloud/bin/nextcloud-home-sweeper.sh
```

**Configuration:**
| Setting | Value | Description |
|---------|-------|-------------|
| Schedule | `03:00` daily | After backups complete |
| Mode | `ALERT_ONLY` | Logs strays, doesn't move them |
| Quarantine | `/space/_services/nextcloud/home_strays/` | Where strays would go if moved |

**Stray File Handling:**
1. Sweeper scans `/mnt/data/nextcloud/data/<user>/files/`
2. Anything not part of Nextcloud internals is flagged
3. In alert-only mode: logs warning and continues
4. In quarantine mode: copies to quarantine directory

### Smoke Tests

Validate pure façade configuration:

```bash
cd ~/miket-infra-devices
python3 tests/nextcloud_smoke.py
```

Tests verify:
- Container is running
- API responds healthy
- Skeleton directory is disabled
- External mounts are configured
- Internal user homes are empty
- Systemd timers are active

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs nextcloud-app
docker logs nextcloud-db
docker logs nextcloud-redis

# Check compose
cd /flux/apps/nextcloud
docker compose config
```

### External Storage Not Mounting

```bash
# Check mounts
docker exec nextcloud-app php occ files_external:list

# Re-scan
docker exec nextcloud-app php occ files:scan mike --path="/mike"

# Check permissions
ls -la /space/mike/
```

### M365 Sync Failures

See: [M365 Sync Runbook](../runbooks/nextcloud_m365_sync.md)

### Performance Issues

```bash
# Check Redis
docker exec nextcloud-redis redis-cli ping

# Check PHP OPcache
docker exec nextcloud-app php -i | grep opcache

# Check cron
docker exec nextcloud-app php occ background:cron
```

## Related Documentation

- [M365 Sync Runbook](../runbooks/nextcloud_m365_sync.md)
- [Nextcloud Client Usage](nextcloud_client_usage.md)
- [Data Lifecycle Spec](../product/DATA_LIFECYCLE_SPEC.md)

