# miket-infra-devices Architecture

**Purpose:** Canonical architecture for endpoint automation, device roles, and service hosting managed by this repository. Aligns with PHC vNext (`PHC_VNEXT_ARCHITECTURE.md`) and the Flux/Space/Time filesystem (`FILESYSTEM_ARCHITECTURE.md`).

## 1) Device roles
- **motoko (server/core):**
  - Runs containers (LiteLLM, Nextcloud), exports `/flux`/`/space`/`/time` via SMB.
  - Hosts Ansible control node and systemd timers (backups, space-mirror, secrets-sync).
  - Cloudflare Tunnel endpoint; never directly internet-exposed.
- **armitage & wintermute (Windows workstations / GPU):**
  - vLLM hosts connected to LiteLLM proxy; mapped drives `X:/S:/T:` for Flux/Space/Time.
  - Remote UX via NoMachine; WinRM used for automation.
- **count-zero & managed macOS devices:**
  - Consume `/flux`/`/space`/`/time` via SMB mounts at `~/.mkt/...` with user-facing symlinks.
  - Run OS cloud ingestion (iCloud/OneDrive) into `/space/devices/<host>/<user>` with loop prevention.

## 2) Automation layers
- **Configuration source:** Ansible playbooks/roles under `ansible/` (device onboarding, mounts, services, secrets-sync).
- **System services:** Managed via systemd (Linux) and scheduled tasks/services (Windows/macOS as applicable). Units must wait for storage before starting services.
- **Health signals:** Devices write `_status.json` to `/space/devices/<hostname>/<user>/` post-mount and post-ingestion.
- **IaC boundary:** Tailscale ACLs, AKV provisioning, Cloudflare Access, and DNS reside in `miket-infra`; consumption and host-level enforcement live here.

## 3) Identity & access
- **Identity provider:** Entra ID for human sign-in and SSO (Nextcloud, Cloudflare Access). Local `mdt` account is the automation identity with sudo/Administrator rights; not used for daily work.
- **Network:** Tailscale mesh with MagicDNS; ACL tags (`tag:server`, `tag:workstation`, `tag:macos`) drive access. Device firewalls mirror the ACL intent for defense in depth.
- **Secrets:** Azure Key Vault is SoR. `secrets-map.yml` declares env var ↔ AKV mappings. `secrets-sync` renders `.env` files with `0600` permissions for services (LiteLLM, backups, SMB, WinRM). 1Password is for humans; Ansible Vault only for transitional bootstraps.

## 4) Storage & data flows
- **Mount UX:** `~/{flux,space,time}` everywhere (drives `X/S/T` on Windows). Scripts resolve hostnames first (MagicDNS) and avoid IPs.
- **Data ingress:** OS clouds → `/space/devices/...`; manual uploads land in `/space/mike/inbox/*` before being curated. No reverse sync from `/space` to clouds.
- **Service data:**
  - **AI fabric:** Models/configs under `/space/ai/` (SoR), ephemeral caches under `/flux/ai/`.
  - **Nextcloud:** External storage to approved `/space/mike/*` folders; internal homes empty. Home sweeper + skeleton disabled remain enforced.
  - **Backups/mirrors:** Restic + space-mirror timers run on motoko using AKV-provisioned credentials.

## 5) Product-facing UX
- **Onboarding:** Bootstrap scripts per OS install Tailscale, configure mounts, and register device tags. Follow with `secrets-sync` and health check.
- **Runbooks:** Operational flows live under `docs/runbooks/` (mount fixes, secret rotation, backup verification). Architecture changes must be reflected here when they alter behavior.
- **Compliance:** Any new device or service must prove alignment with PHC vNext invariants (Entra-first, `/space` SoR, Cloudflare ingress, AKV secrets) before deployment.

## 6) Boundary with miket-infra (platform)
- **miket-infra owns:** Tailnet ACLs and tag definitions (Terraform), Cloudflare Access/Tunnel policy, DNS, and Entra application/SSO configuration. It also provisions AKV and identity resources.
- **miket-infra-devices owns:** Host-side automation (Ansible playbooks, bootstrap scripts, systemd timers), device tagging, and consumption of the platform contracts (ACL tags, AKV secret names, Cloudflare endpoints).
- **Integration contract:**
  - Device scripts apply tags defined in `miket-infra`; they do not redefine ACL intent here.
  - Services consume secrets declared in `secrets-map.yml`, which map to AKV names provisioned upstream.
  - Public ingress is always via Cloudflare Tunnel + Access + Entra SSO; no host in this repo is directly exposed.
  - Any platform changes (ACLs, DNS, SSO) must be landed in `miket-infra` first, then reflected here by consuming the new values.
