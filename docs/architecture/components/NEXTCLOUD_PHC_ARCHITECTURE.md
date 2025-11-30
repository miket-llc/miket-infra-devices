# Nextcloud PHC Component Architecture

**Scope:** Nextcloud deployment on motoko within the PHC vNext architecture.

## 1) Role in PHC
- Acts as a **pure façade** over `/space`; internal Nextcloud user homes remain empty (skeleton files disabled, home sweeper enforced).
- Provides collaboration and sync clients without becoming a new SoR.
- Runs on motoko inside container stack managed by Ansible (`nextcloud_server` role).

## 2) Ingress & identity
- **Ingress:** Cloudflare Tunnel terminates public access; Cloudflare Access enforces Entra SSO. motoko is never directly exposed to the internet.
- **SSO:** Entra OIDC app registration (managed via `miket-infra`) provides authentication; no local accounts except the bootstrap admin.
- **Network:** Internal access via Tailscale hostnames; external only through Cloudflare Access.

## 3) Storage bindings
- **Source of Record:** `/space` per `FILESYSTEM_ARCHITECTURE.md`.
- **External storage mappings:** Only approved `/space/mike/*` collections (e.g., `work`, `media`, `finance`, `inbox`). Prohibited: `/space/projects/**`, `/space/code/**`, `/space/dev/**`, automation or secrets paths.
- **Runtime paths:** Container data/config under `/space/apps/nextcloud/` with database/redis volumes; backups handled via restic/space-mirror from `/space`.

## 4) Operational guardrails
- **No circular syncs:** Do not connect Nextcloud to upstream cloud drives that already ingest into `/space`.
- **Service dependencies:** Nextcloud stack requires storage mounts ready before container start and AKV-sourced env files present.
- **Client guidance:** Clients sync against Nextcloud, which surfaces `/space`; caches belong under `~/nc` (user-local) and must not be treated as SoR.

## 5) Related assets
- Deployment role: `ansible/roles/nextcloud_server/`
- Client role: `ansible/roles/nextcloud_client/`
- Guides: `docs/guides/nextcloud_on_motoko.md`, `docs/guides/nextcloud_client_usage.md`
- Tests: `tests/nextcloud_smoke.py`
