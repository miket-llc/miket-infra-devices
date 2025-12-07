# Filesystem Architecture (Flux/Space/Time)

**Status:** ACTIVE • **Version:** 2.1 • **Scope:** All PHC devices and services

The Flux/Space/Time filesystem is the storage backplane for the Personal Hybrid Cloud (PHC). `/space` is the **sole Source of Record (SoR)**, `/flux` is the active workspace, and `/time` is the backup/history tier. All ingestion (devices, M365, OS-native clouds) converges into `/space`, and all services consume data from `/space` without creating alternate SoRs.

## 1) Pillars and intent
| Pillar | Path (UX) | Purpose | Characteristics |
|:---|:---|:---|:---|
| **Flux** | `~/flux` | **High-energy state.** Active projects, code, WIP. | Fast, hot, local snapshots. |
| **Space** | `~/space` | **The Infinite.** Archives, media, datasets, cloud mirrors. | Vast, reliable, SoR. |
| **Time** | `~/time` | **History.** Backups, time-travel. | Read-mostly, recovery. |

## 2) Invariants (do not break)
1. `/space` is the only SoR; do **not** mirror from `/space` into other clouds.
2. `/flux` and `/time` are caches/backups and can be rebuilt from `/space`.
3. Ingestion only flows **into** `/space` (M365/iCloud/OneDrive → `/space/devices/...`).
4. Backups run **from** `/space` → `/time`/B2; never the reverse.
5. Services (Nextcloud, LiteLLM, vLLM, etc.) read/write through `/space` and must not invent new storage layouts.
6. External mounts (SMB/NFS) present `/flux`, `/space`, `/time` via canonical paths; avoid hardcoded IPs.

## 3) Layout & permissions
- **Primary storage host (akira):** `/space` (SoR, btrfs on 18TB external), `/flux` (runtime, NVMe), `/time` (backups, NVMe). Exported via SMB. Hosts Nextcloud and space-mirror jobs. (Per ADR-0010, migrated from motoko 2025-12.)
- **Secondary host (motoko):** `/time` (Time Machine backups), `/flux` (local runtime). No longer hosts `/space` SoR.
- **Client UX paths:** `~/{flux,space,time}` on every OS. These are symlinks or mapped drives masking implementation paths.
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

## 7) Service consumption rules
- **Nextcloud:** Operates as a façade over `/space` only. Internal Nextcloud homes stay empty; external storage maps approved `/space/mike/*` folders. Public ingress only through Cloudflare Tunnel + Access + Entra SSO. See `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md`.
- **AI fabric (LiteLLM/vLLM):** Read/write datasets and model artifacts from `/space`; avoid storing durable data under `/flux`.
- **Automation/state:** Ansible roles store cached artifacts under `/flux` when needed but persist generated outputs to `/space`.

## 8) Implementation guardrails
- Prefer hostnames (MagicDNS/Tailscale) over IPs in all mount scripts.
- All mount/service units must include `Requires=`/`After=` dependencies to ensure storage is online before services start.
- Permissions: exported shares restrict write access to authorized users; automation writes use the `mdt` account or service accounts as defined in `docs/reference/account-architecture.md`.
- New storage consumers must document their paths in `docs/reference/` and align with these invariants before deployment.
