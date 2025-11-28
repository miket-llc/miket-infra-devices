# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Nextcloud Server Role

Deploys Nextcloud server stack on motoko with /space integration per PHC invariants.

## Overview

This role deploys a containerized Nextcloud stack including:
- Nextcloud application (Apache)
- PostgreSQL database
- Redis cache

All data is stored on `/space` (System of Record) with runtime components on `/flux`.

## Directory Structure

```
/flux/apps/nextcloud/           # Runtime stack
├── docker-compose.yml
├── config/
│   └── rclone-m365.conf
└── bin/
    ├── sync-m365.sh
    └── nextcloud-db-backup.sh

/flux/runtime/secrets/
└── nextcloud.env               # Secrets from AKV

/space/_services/nextcloud/     # App data (SoR)
├── data/                       # Nextcloud data
├── db/                         # PostgreSQL data
└── db-backups/                 # DB dumps

/space/_ops/logs/nextcloud/     # Logs

/space/mike/inbox/ms365/        # M365 ingestion target
```

## External Storage Mounts

The role configures Nextcloud external storage to mount existing `/space/mike` directories:

| NC Folder | Local Path |
|-----------|------------|
| work | /space/mike/work |
| media | /space/mike/media |
| finance | /space/mike/finance |
| assets | /space/mike/assets |
| camera | /space/mike/camera |
| inbox | /space/mike/inbox |
| ms365 | /space/mike/inbox/ms365 |

**NEVER mount** (excluded by design):
- `/space/mike/dev`
- `/space/mike/code`
- `/space/mike/art`
- `/space/projects/**`

## Prerequisites

1. Azure Key Vault secrets must be provisioned:
   - `nextcloud-db-user`
   - `nextcloud-db-password`
   - `nextcloud-admin-user`
   - `nextcloud-admin-bootstrap-password`
   - `m365-nextcloud-client-id`
   - `m365-nextcloud-client-secret`
   - `nextcloud-redis-password`

2. Secrets sync must be run first:
   ```bash
   ansible-playbook playbooks/secrets-sync.yml --limit motoko
   ```

## Usage

```bash
# Deploy Nextcloud stack
ansible-playbook playbooks/motoko/deploy-nextcloud.yml --limit motoko

# Validate deployment
ansible-playbook playbooks/motoko/deploy-nextcloud.yml --limit motoko --tags validate
```

## Endpoints

- **Internal**: `http://nextcloud.motoko:8080` (via Tailscale)
- **External**: `https://nextcloud.miket.io` (via Cloudflare Access)

## Scheduled Jobs

| Job | Schedule | Description |
|-----|----------|-------------|
| `nextcloud-m365-sync.timer` | Hourly | M365 → /space/mike/inbox/ms365 |
| `nextcloud-db-backup.timer` | 02:00 | DB dump before restic |

## Backup Integration

The data-lifecycle role's restic jobs should include:
- `/space/_services/nextcloud/**`

Verify with: `restic snapshots | grep nextcloud`

## See Also

- [Nextcloud on Motoko Guide](../../../docs/guides/nextcloud_on_motoko.md)
- [M365 Sync Runbook](../../../docs/runbooks/nextcloud_m365_sync.md)
- [Client Usage Guide](../../../docs/guides/nextcloud_client_usage.md)

