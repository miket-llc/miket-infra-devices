# Filesystem Architecture (Flux/Space/Time/Matter)

**Status:** ACTIVE • **Version:** 2.2 • **Scope:** All PHC devices and services

The Flux/Space/Time/Matter filesystem is the storage backplane for the Personal Hybrid Cloud (PHC). `/space` is the **sole Source of Record (SoR)**, `/flux` is the active workspace, `/time` is the backup/history tier, and `/matter` is the derived/cached data tier. All ingestion (devices, M365, OS-native clouds) converges into `/space`, and all services consume data from `/space` without creating alternate SoRs.

## 1) Pillars and intent
| Pillar | Path (UX) | Purpose | Characteristics |
|:---|:---|:---|:---|
| **Flux** | `~/flux` | **High-energy state.** Active projects, code, WIP. | Fast, hot, local snapshots. |
| **Space** | `~/space` | **The Infinite.** Archives, media, datasets, cloud mirrors. | Vast, reliable, SoR. |
| **Time** | `~/time` | **History.** Backups, time-travel. | Read-mostly, recovery. |
| **Matter** | `~/matter` | **Instantiated form.** Derived data, caches, indexes. | Fast NVMe, rebuildable. |

## 2) Invariants (do not break)
1. `/space` is the only SoR; do **not** mirror from `/space` into other clouds.
2. `/flux`, `/time`, and `/matter` are caches/backups/derived and can be rebuilt from `/space` or source systems.
3. Ingestion only flows **into** `/space` (M365/iCloud/OneDrive → `/space/devices/...`).
4. Backups run **from** `/space` → `/time`/B2; never the reverse.
5. Services (Nextcloud, LiteLLM, vLLM, etc.) read/write through `/space` and must not invent new storage layouts.
6. External mounts (SMB/NFS) present `/flux`, `/space`, `/time`, `/matter` via canonical paths; avoid hardcoded IPs.
7. `/matter` contains only derived, materialized, or cached data that can be regenerated from `/space`, `/flux`, or external sources.

## 3) Layout & permissions
- **Primary storage host (akira):** `/space` (SoR, btrfs on 18TB WD external), `/flux` (Samsung 990 PRO 4TB NVMe), `/time` (backups, 20TB WD external), `/matter` (Crucial P310 4TB NVMe, derived/cached data). Exported via SMB. Hosts Nextcloud and space-mirror jobs. (Per ADR-0010, migrated from motoko 2025-12.)
- **Secondary host (motoko):** `/time` (Time Machine backups), `/flux` (local runtime). No longer hosts `/space` SoR.
- **Client UX paths:** `~/{flux,space,time,matter}` on every OS. These are symlinks or mapped drives masking implementation paths.
- **Do not expose:** `/space/projects/**`, `/space/dev/**`, `/space/code/**`, or any internal automation state via sync services.

## 4) Mount patterns per OS
- **macOS:** Implementation mounts at `~/.mkt/{flux,space,time}` with symlinks `~/{flux,space,time}`. SMB target `//akira/space` for `/space`, `//motoko/time` for `/time`. Use hostname resolution first (MagicDNS).
- **Windows:** Drives `X:` (flux), `S:` (space), `T:` (time) mapped to `\\akira\space` and `\\motoko\time`. Junctions excluded from any OS cloud ingestion.
- **Linux:** `/mnt/{flux,space,time}` or user-level `~/.mkt/...` (FUSE/GVFS). Symlinks in `$HOME` mirror the canonical naming. Note: akira has local `/space`; other nodes mount via SMB.

## 5) Ingestion & device reporting
- **OS-native clouds:** iCloud/OneDrive ingest **into** `/space/devices/<host>/<user>/...` with loop prevention (`rsync --no-links`, `robocopy /XJ`). Never sync mount points back to the cloud providers.
- **Device health:** Each device writes `_status.json` to `/space/devices/<hostname>/<username>/` after mount/sync success for observability.

## 6) Backups & mirrors
- **Primary backup:** Restic from `/space` → Backblaze B2 (credentials via AKV → `/etc/miket/storage-credentials.env`).
- **Local history:** `/time` holds restic snapshots and any time-based archives. Treat `/time` as replaceable from `/space` + B2.
- **Mirrors:** `space-mirror` jobs mirror `/space` to B2 object storage; ensure credentials come from AKV and jobs run via systemd with `EnvironmentFile`.

## 7) Matter: Derived data tier
`/matter` is the performance-optimized tier for derived, materialized, and cached data. Nothing on `/matter` is a system of record—everything can be regenerated.

**Directory structure:**
```
/matter/
├── ai/                    # AI/ML artifacts
│   ├── embeddings/        # Vector embeddings
│   ├── vectors/           # Vector indexes
│   ├── chunks/            # RAG chunk caches
│   └── rag/               # RAG retrieval results
├── build/                 # Build artifacts
│   ├── compiled/          # Compiled assets
│   └── artifacts/         # Build outputs
├── cache/                 # Package manager caches (symlinked from ~/)
│   ├── pip/               # ~/.cache/pip → /matter/cache/pip
│   ├── pnpm/              # ~/.local/share/pnpm → /matter/cache/pnpm
│   ├── cargo/             # ~/.cargo/registry → /matter/cache/cargo/registry
│   ├── npm/               # ~/.npm → /matter/cache/npm
│   ├── huggingface/       # ~/.cache/huggingface → /matter/cache/huggingface
│   └── torch/             # ~/.cache/torch → /matter/cache/torch
├── data/                  # Data science scratch
│   ├── parquet/           # Intermediate datasets
│   ├── scratch/           # Temporary analysis data
│   └── experiments/       # Experiment outputs
├── indexes/               # Search indexes
│   ├── opensearch/
│   ├── meilisearch/
│   └── tantivy/
└── staging/               # Staging areas
    ├── imports/           # Staged imports before /flux
    └── exports/           # Read-optimized hot copies
```

**Semantic contract:** If `/matter` is wiped, services should regenerate their data from `/space`, `/flux`, or external sources without data loss.

## 8) Service consumption rules
- **Nextcloud:** Operates as a façade over `/space` only. Internal Nextcloud homes stay empty; external storage maps approved `/space/mike/*` folders. Public ingress only through Cloudflare Tunnel + Access + Entra SSO. See `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md`.
- **AI fabric (LiteLLM/vLLM):** Read/write datasets and model artifacts from `/space`; cache embeddings and indexes on `/matter`.
- **Automation/state:** Ansible roles store cached artifacts under `/flux` when needed but persist generated outputs to `/space`.

## 9) Implementation guardrails
- Prefer hostnames (MagicDNS/Tailscale) over IPs in all mount scripts.
- All mount/service units must include `Requires=`/`After=` dependencies to ensure storage is online before services start.
- Permissions: exported shares restrict write access to authorized users; automation writes use the `mdt` account or service accounts as defined in `docs/reference/account-architecture.md`.
- New storage consumers must document their paths in `docs/reference/` and align with these invariants before deployment.
