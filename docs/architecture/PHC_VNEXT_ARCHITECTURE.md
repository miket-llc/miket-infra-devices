# PHC vNext Architecture

**Scope:** MikeT LLC Personal Hybrid Cloud (PHC) across miket-infra + miket-infra-devices

This document is the canonical architecture for PHC vNext. It anchors identity on Entra ID, networking on Tailscale + Cloudflare Access, storage on the Flux/Space/Time backplane, and compute on motoko plus managed endpoints. Component architectures (Nextcloud, Secrets) inherit these rules and must not diverge.

## 1) Core principles
1. **Entra-first identity:** All users, service principals, and public ingress rely on Entra ID. Local accounts exist only for automation bootstraps (`mdt`).
2. **Backplane:** Flux/Space/Time is the storage fabric; `/space` is the SoR. All services consume `/space` and respect the invariants in `FILESYSTEM_ARCHITECTURE.md`.
3. **Zero-trust network:** Tailscale provides device-to-device mesh with ACLs in `miket-infra`; Cloudflare Tunnel + Access is the only internet ingress, enforcing Entra SSO.
4. **IaC/CaC split:** `miket-infra` owns Terraform/Terragrunt for identity/network/storage; `miket-infra-devices` owns Ansible/systemd for endpoints and services.
5. **Secrets:** Azure Key Vault is the SoR for automation secrets; `.env` files are AKV-synced caches; 1Password is for humans; Ansible Vault is transitional only.
6. **Services are façades:** Nextcloud and other apps surface `/space` without becoming new SoRs.

## 2) Control planes and roles
- **Identity:** Entra ID tenants + app registrations (e.g., Nextcloud OIDC). Device automation uses local `mdt` accounts but authenticates to services with Entra where supported.
- **Network:**
  - **Tailscale mesh:** MagicDNS hostnames align with Ansible inventory; ACLs scoped by device tags (`tag:server`, `tag:workstation`, `tag:macos`, etc.).
  - **Cloudflare Access:** Public ingress fronting motoko services (Nextcloud) via Cloudflare Tunnel; Access policies enforce Entra SSO.
- **Storage:** Motoko exports `/flux`, `/space`, `/time` via SMB. Device mounts follow `FILESYSTEM_ARCHITECTURE.md`.
- **Compute:**
  - **Core host:** `motoko` (Fedora) runs containers (LiteLLM, Nextcloud), storage exports, and Ansible control.
  - **Edge GPUs:** `armitage`, `wintermute` run vLLM workloads and workstation UX.
  - **Clients:** macOS devices (count-zero, managed MBP) consume storage and remote services; all devices report health to `/space/devices`.

## 3) Platform services
- **AI Fabric:** LiteLLM on motoko proxies to local vLLM backends (armitage, wintermute) and cloud fallbacks. Model artifacts and configs live under `/space`.
- **Storage services:** `space-mirror` to B2, restic backups from `/space`, and health manifests under `/space/devices`. Share definitions live in Ansible roles.
- **Nextcloud:** Single deployment on motoko with external storage to `/space`; ingress only through Cloudflare Tunnel + Access + Entra SSO. See component doc.
- **Remote access:** Tailscale SSH for admin access; NoMachine for desktop UX. RDP/VNC references are retired unless explicitly noted in runbooks.

## 4) Security & secrets
- **Secrets workflow:** AKV names are mapped in `ansible/secrets-map.yml`; `ansible/playbooks/secrets-sync.yml` writes `.env` files with `0600` perms. Services reference env files via `EnvironmentFile`. 1Password is for humans/break glass; Ansible Vault only for short-lived bootstrap.
- **Ingress controls:** Cloudflare Tunnel agents run on motoko; Access policies enforce Entra SSO and device posture. motoko is never directly exposed to the internet.
- **Data boundaries:** `/space` is SoR; `/flux` and `/time` are ephemeral. Nextcloud internal storage remains empty beyond config; all user data flows through `/space` external storage mounts.

## 5) IaC / CaC ownership
- **miket-infra (Terraform/Terragrunt):** Entra applications, Cloudflare Access policies, AKV provisioning, Tailscale ACL definitions, storage accounts, DNS.
- **miket-infra-devices (Ansible/systemd):** Device onboarding, mounts, service units (LiteLLM, vLLM, Nextcloud), secrets sync consumers, timers, and health reporting.
- **Change management:** Architectural changes land here; implementation specifics live in roles/playbooks. New services must declare storage paths and secret mappings up front.

## 6) Component architecture index
- **Filesystem:** `docs/architecture/FILESYSTEM_ARCHITECTURE.md`
- **Devices & endpoint automation:** `docs/architecture/Miket_Infra_Devices_Architecture.md`
- **Nextcloud:** `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md`
- **Secrets:** `docs/architecture/components/SECRETS_ARCHITECTURE.md`

All other design notes must defer to these canonical documents or be archived if conflicting.
