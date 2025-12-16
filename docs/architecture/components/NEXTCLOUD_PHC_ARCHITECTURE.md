# Nextcloud PHC Component Architecture

**Scope:** Nextcloud deployment within the PHC vNext architecture.

> **Note:** Per ADR-0010 (2025-12), Nextcloud was migrated from motoko to akira. This document reflects the current akira deployment.

## 1) Role in PHC
- Acts as a **pure façade** over `/space`; internal Nextcloud user homes remain empty (skeleton files disabled, home sweeper enforced).
- Provides collaboration and sync clients without becoming a new SoR.
- Runs on **akira** inside container stack managed by Ansible (`nextcloud_server` role).

## 2) Ingress & identity
- **Ingress:** Cloudflare Tunnel terminates public access; Cloudflare Access enforces Entra SSO. akira is never directly exposed to the internet.
- **SSO:** Entra OIDC app registration (managed via `miket-infra`) provides authentication; no local accounts except the bootstrap admin.
- **Network:** Internal access via Tailscale hostnames (`akira.pangolin-vega.ts.net`); external only through Cloudflare Access (`nextcloud.miket.io`).

## 3) Storage bindings
- **Source of Record:** `/space` per `FILESYSTEM_ARCHITECTURE.md`. Physically located on akira's WD Red 18TB external drive.
- **External storage mappings:** Only approved `/space/mike/*` collections (e.g., `work`, `media`, `finance`, `inbox`). Prohibited: `/space/projects/**`, `/space/code/**`, `/space/dev/**`, automation or secrets paths.
- **Runtime paths:**
  - App runtime: `/flux/apps/nextcloud/` (on akira's NVMe)
  - Database: `/flux/dbs/nextcloud/` (PostgreSQL data on NVMe for performance)
  - Secrets: `/flux/runtime/secrets/nextcloud.env` (AKV-synced)
  - Config backups: `/space/_services/nextcloud/config/`
  - DB snapshots: `/space/_services/nextcloud/db-snapshots/`
  - Backups handled via space-mirror (B2) running on akira.

## 4) Operational guardrails
- **No circular syncs:** Do not connect Nextcloud to upstream cloud drives that already ingest into `/space`.
- **Service dependencies:** Nextcloud stack requires storage mounts ready before container start and AKV-sourced env files present.
- **Client guidance:** Clients sync against Nextcloud, which surfaces `/space`; caches belong under `~/Cloud` (user-local) and must not be treated as SoR.

## 5) Related assets
- Deployment role: `ansible/roles/nextcloud_server/`
- Client role: `ansible/roles/nextcloud_client/`
- Storage setup: `ansible/roles/akira_space/`
- Migration playbooks: `ansible/playbooks/migration/`
- Runbooks: `docs/runbooks/SPACE_NEXTCLOUD_MIGRATION.md`, `docs/runbooks/NEXTCLOUD_ROLLBACK.md`
- ADR: `docs/architecture/adr/ADR-0010-space-nextcloud-migration-motoko-to-akira.md`
- Tests: `tests/nextcloud_smoke.py`
