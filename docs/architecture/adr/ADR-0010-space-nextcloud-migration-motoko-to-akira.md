# ADR-0010: Migration of /space and Nextcloud from motoko to akira

**Status:** Accepted  
**Date:** 2025-12-07  
**Decision Makers:** miket-infra-devices team  
**Context:** PHC vNext Storage Backplane Migration

## Summary

Migrate the `/space` System of Record (SoR) and the Nextcloud PHC service from `motoko` to `akira`, while preserving all filesystem invariants, the Nextcloud façade pattern, and maintaining a clean rollback path.

## Context

### Current State

- **motoko** currently hosts:
  - `/space` on a WD 20TB external USB drive (partition: 10.9TB, UUID: `7f5e508d-fcac-4d18-80ca-84c857b20b40`, ext4)
  - `/time` on the same drive (partition: 7.3TB, UUID: `f54cf57c-e434-45f5-bde3-cc706ffbe849`)
  - Nextcloud container stack (app + PostgreSQL + Redis)
  - `space-mirror` B2 sync job
  - M365 ingestion job (rclone → `/space/mike/inbox/ms365`)
  - LiteLLM proxy and vLLM embeddings services

- **akira** currently hosts:
  - `/space` on WD Red 18TB external USB drive (UUID: `9f387c92-613e-44fb-a6c4-3878b95905f3`, btrfs)
  - `/flux` on Samsung 990 PRO 4TB NVMe
  - `/time` on Crucial P310 4TB NVMe
  - AMD Strix Point APU with ROCm for AI workloads

### Motivation

1. **Hardware reliability:** akira's storage subsystem (newer hardware, faster NVMe for `/flux`) provides better performance and reliability for the PHC storage backplane.

2. **Workload separation:** motoko can focus on AI inference (LiteLLM proxy, embeddings) while akira handles storage-intensive Nextcloud operations.

3. **External drive stability:** akira's USB-C connection to the WD Red 18TB is more stable than motoko's aging USB hub configuration.

4. **Capacity:** akira's 18TB drive provides ample headroom for `/space` growth.

## Decision

### Target End State

**akira will host:**
- Physical `/space` volume (SoR) on the WD Red 18TB external drive
- Nextcloud container stack (app + PostgreSQL + Redis)
- `space-mirror` B2 sync job
- M365 ingestion job

**motoko will continue to host:**
- `/time` (Time Machine backups for count-zero)
- LiteLLM proxy and vLLM embeddings services
- Ansible control node responsibilities
- Will no longer host `/space` or Nextcloud post-migration

### Architecture Changes

#### Storage Layout on akira

```
/space (btrfs, UUID: 9f387c92-613e-44fb-a6c4-3878b95905f3)
├── mike/                    # User content (SoR)
│   ├── work/
│   ├── media/
│   ├── finance/
│   ├── assets/
│   ├── camera/
│   └── inbox/
│       └── ms365/           # M365 ingestion target
├── _services/
│   └── nextcloud/
│       ├── config/          # Nextcloud config backups
│       └── db-snapshots/    # PostgreSQL dumps
├── _ops/
│   ├── data-estate/
│   │   └── markers/         # Job status markers
│   └── logs/
│       └── data-lifecycle/  # Backup/mirror logs
└── ...                      # Other canonical directories

/flux (ext4, Samsung 990 PRO 4TB)
├── apps/
│   └── nextcloud/
│       ├── docker-compose.yml
│       ├── config/          # Runtime config (transient)
│       └── bin/             # Helper scripts
├── dbs/
│   └── nextcloud/           # PostgreSQL data directory
├── runtime/
│   └── secrets/
│       └── nextcloud.env    # AKV-synced secrets
└── containers/              # Podman storage
```

#### Nextcloud Path Mappings

The Nextcloud container will mount `/space/mike/*` directories exactly as on motoko:

| External Storage Name | Container Mount | Host Path |
|-----------------------|-----------------|-----------|
| work | /external/work | /space/mike/work |
| media | /external/media | /space/mike/media |
| finance | /external/finance | /space/mike/finance |
| assets | /external/assets | /space/mike/assets |
| camera | /external/camera | /space/mike/camera |
| inbox | /external/inbox | /space/mike/inbox |
| ms365 | /external/ms365 | /space/mike/inbox/ms365 |

### Migration Strategy

#### Phase 1: Pre-Cutover (No User Impact)

1. **Bulk data copy** from `motoko:/space` to `akira:/space` via Tailscale (rsync with `--delete`)
2. **Configure repeatable delta sync** for just-before-cutover synchronization
3. **Deploy `space-mirror` job on akira** (but keep motoko's job as primary)

#### Phase 2: Stage Nextcloud (Dark)

1. Deploy Nextcloud stack on akira under `/flux/apps/nextcloud/`
2. Restore database from motoko's latest snapshot
3. Configure external storage mounts
4. Validate via tailnet-only access (`https://akira.pangolin-vega.ts.net:8080`)

#### Phase 3: Coordinated Cutover (~15 min window)

1. Put motoko Nextcloud in maintenance mode
2. Final delta sync of `/space`
3. Export final DB snapshot from motoko, import on akira
4. Stop motoko Nextcloud; start akira Nextcloud
5. Switch `space-mirror` and M365 jobs from motoko to akira
6. Smoke test via tailnet
7. Signal `miket-infra` team to update Cloudflare tunnel

#### Phase 4: Post-Cutover

1. Keep motoko Nextcloud offline but intact for rollback window (7 days)
2. Monitor akira services and B2 sync health
3. After rollback window: cleanup motoko Nextcloud runtime (preserve config/snapshots for 30 days)

### Rollback Plan

If critical issues arise within the rollback window:

1. Put akira Nextcloud in maintenance mode
2. Export akira DB snapshot (capture any new writes)
3. Sync `/space` changes back to motoko (delta only)
4. Import DB snapshot to motoko
5. Start motoko Nextcloud
6. Signal `miket-infra` to revert tunnel
7. Disable akira services

### Invariants Preserved

1. ✅ `/space` remains the sole SoR
2. ✅ Directory structure under `/space/mike/*` unchanged
3. ✅ Nextcloud façade pattern maintained (no user files in internal data)
4. ✅ Secrets remain in Azure Key Vault
5. ✅ `space-mirror` continues to B2 bucket `miket-space-mirror`
6. ✅ External FQDN `nextcloud.miket.io` unchanged (tunnel update by `miket-infra`)

## Alternatives Considered

### Alternative 1: NFS Mount from akira to motoko

**Rejected** because:
- Adds network dependency to storage path
- Complicates failure modes (network partition = data unavailable)
- Doesn't align with "local storage is SoR" principle

### Alternative 2: Keep Nextcloud on motoko, Only Move /space

**Rejected** because:
- Requires NFS/SMB mount from motoko to akira's `/space`
- Introduces latency for every file operation
- Nextcloud performance would degrade

### Alternative 3: Full Host Migration (All Services)

**Rejected** because:
- LiteLLM and vLLM on motoko serve AI fabric requests from multiple nodes
- motoko's `/time` hosts Time Machine backups with established SMB paths
- Over-scoped for current needs

## Consequences

### Positive

- cleaner hardware separation: storage workloads on akira, AI workloads on motoko
- Improved storage performance (faster drive, better USB connection)
- Simplified disaster recovery (fewer services per host)

### Negative

- Migration window requires coordination with `miket-infra` team
- Brief service interruption during cutover
- Additional complexity in secrets-map.yml (akira gets Nextcloud secrets)

### Neutral

- SMB clients mounting `/space` from motoko must be reconfigured to mount from akira (handled by `miket-infra-devices` mount roles)

## Implementation

### Ansible Roles/Playbooks

| Component | Path |
|-----------|------|
| akira /space setup | `roles/akira_space/` |
| akira Nextcloud deploy | `roles/nextcloud_server/` (parameterized for akira) |
| Data sync playbook | `playbooks/migration/space-migration-sync.yml` |
| Cutover playbook | `playbooks/migration/nextcloud-cutover.yml` |
| Rollback playbook | `playbooks/migration/nextcloud-rollback.yml` |
| motoko cleanup | `playbooks/motoko/nextcloud-decommission.yml` |

### Secrets Changes

Update `secrets-map.yml` to deploy Nextcloud secrets to akira:

```yaml
nextcloud:
  hosts: [akira]  # Changed from [motoko]
  env_file: /flux/runtime/secrets/nextcloud.env
  ...
```

### Runbooks

- `docs/runbooks/SPACE_NEXTCLOUD_MIGRATION.md` - Full migration procedure
- `docs/runbooks/NEXTCLOUD_ROLLBACK.md` - Emergency rollback procedure

## References

- `docs/architecture/FILESYSTEM_ARCHITECTURE.md` - Flux/Space/Time invariants
- `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md` - Nextcloud façade pattern
- `devices/akira/config.yml` - akira hardware and storage layout
- `devices/motoko/config.yml` - motoko hardware and storage layout

