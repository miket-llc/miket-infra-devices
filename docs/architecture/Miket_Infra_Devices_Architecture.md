# miket-infra-devices Architecture

**Purpose:** Canonical architecture for endpoint automation, device roles, and service hosting managed by this repository. Aligns with PHC vNext (`PHC_VNEXT_ARCHITECTURE.md`) and the Flux/Space/Time filesystem (`FILESYSTEM_ARCHITECTURE.md`).

> **Subordination note:** This document is subordinate to the canonical platform architecture `MIKET_INFRA_ARCHITECTURE.md` in `miket-infra`. Platform-level decisions (ACLs, DNS, SSO, Cloudflare policy, AKV provisioning) are authoritative there; this document covers host-side implementation and consumption of those contracts.

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

## 5) Monitoring & observability
- **Netdata Cloud (Homelab):** All PHC nodes run standalone Netdata agents claimed to Netdata Cloud (Homelab subscription). Cloud is the **primary monitoring UI**; local dashboards are secondary (break-glass, tailnet-only). Uses STABLE release channel by default.
- **Architecture:**
  - Each node (motoko, atom, count-zero, wintermute, armitage) runs a standalone Netdata agent
  - Agents connect to Netdata Cloud via ACLK (Agent-Cloud Link) for unified monitoring
  - **NO parent/child streaming** - Cloud handles aggregation and long-term retention
  - motoko is no longer a local parent aggregator
- **Primary UI:** https://app.netdata.cloud - provides unified dashboards, alerting, historical views, and cross-node correlation for all PHC nodes
- **Local dashboards (secondary):** Available on each node via tailnet for break-glass debugging:
  - `http://<hostname>.pangolin-vega.ts.net:19999`
  - Bound to `127.0.0.1` and Tailscale IP only
- **Windows support:** Fully enabled (Homelab subscription unlocks Windows agents). wintermute and armitage appear in Cloud with full metrics.
- **Cloud/ACLK enabled:**
  - `[cloud] enabled = yes` in `cloud.conf`
  - Agents claimed to Homelab Space via `netdata-claim.sh`
  - Claim tokens sourced from Azure Key Vault (`netdata-cloud-claim-token`, `netdata-cloud-space-id`)
  - ACLK connection is required for Cloud visibility
- **Security:** Netdata agents bound to localhost + Tailscale IP. Firewall rules restrict local dashboard access to Tailscale CGNAT range (`100.64.0.0/10`). Cloud connection uses TLS/MQTT.
- **IaC/CaC:** All Netdata config is managed via `ansible/roles/netdata/` (templates: `netdata.conf.j2`, `stream.conf.j2`, `cloud.conf.j2`, `go.d.conf.j2`). Claiming is idempotent via `claim.yml` tasks. No manual edits on hosts.
- **Collectors (per-node):** Configurable via Ansible variables (`netdata_enable_*`):
  - **Containers (cgroups.plugin):** Monitors Podman containers on Linux nodes (motoko, AI node). Charts: CPU, memory, I/O, network per container.
  - **Nvidia GPU (nvidia_smi):** GPU utilization, VRAM, temps on motoko (RTX 2080) and AI node. Requires NVIDIA drivers.
  - **Linux Sensors (sensors):** CPU temps, fans, voltages via lm-sensors on all Linux nodes.
  - **LiteLLM Prometheus:** Scrapes `/metrics` from LiteLLM proxy (when exposing metrics is enabled). Config ready; endpoint pending LiteLLM config.
  - Config files: `/etc/netdata/go.d.conf`, `/etc/netdata/go.d/*.conf`
- **Backup alignment:**
  - Config files (`/etc/netdata/`) are reproducible from git templates
  - Data paths (`/var/cache/netdata/`, `/var/lib/netdata/`) contain ephemeral metrics - NOT a System of Record
  - Netdata Cloud retains historical data; local storage is short-term buffer only
  - Does NOT violate `/space` SoR invariants
- **Secrets:** Claim tokens stored in AKV, synced via `secrets-map.yml` → `/flux/runtime/secrets/netdata.env`
- **Deployment:** `ansible-playbook playbooks/deploy-netdata.yml` to deploy, configure, and claim agents
- **Future:** AI node (Minisforum X1) will be added to `netdata_nodes` group when provisioned

## 6) Product-facing UX
- **Onboarding:** Bootstrap scripts per OS install Tailscale, configure mounts, and register device tags. Follow with `secrets-sync` and health check.
- **Runbooks:** Operational flows live under `docs/runbooks/` (mount fixes, secret rotation, backup verification). Architecture changes must be reflected here when they alter behavior.
- **Compliance:** Any new device or service must prove alignment with PHC vNext invariants (Entra-first, `/space` SoR, Cloudflare ingress, AKV secrets) before deployment.

## 7) Boundary with miket-infra (platform)
- **miket-infra owns:** Tailnet ACLs and tag definitions (Terraform), Cloudflare Access/Tunnel policy, DNS, and Entra application/SSO configuration. It also provisions AKV and identity resources.
- **miket-infra-devices owns:** Host-side automation (Ansible playbooks, bootstrap scripts, systemd timers), device tagging, and consumption of the platform contracts (ACL tags, AKV secret names, Cloudflare endpoints).
- **Integration contract:**
  - Device scripts apply tags defined in `miket-infra`; they do not redefine ACL intent here.
  - Services consume secrets declared in `secrets-map.yml`, which map to AKV names provisioned upstream.
  - Public ingress is always via Cloudflare Tunnel + Access + Entra SSO; no host in this repo is directly exposed.
  - Any platform changes (ACLs, DNS, SSO) must be landed in `miket-infra` first, then reflected here by consuming the new values.
