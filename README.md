# miket-infra-devices

Endpoint automation and UX for the MikeT PHC devices, aligned to the platform decisions in **miket-infra** and the PHC vNext architecture.

## Start here
- **PHC big picture:** `docs/architecture/PHC_VNEXT_ARCHITECTURE.md`
- **Device scope & contracts:** `docs/architecture/Miket_Infra_Devices_Architecture.md`
- **Storage & façade services:** `docs/architecture/FILESYSTEM_ARCHITECTURE.md` and `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md`
- **Operational status & work logs:** `docs/product/STATUS.md`, `docs/product/EXECUTION_TRACKER.md`, and `docs/communications/COMMUNICATION_LOG.md`

## What this repo owns
- Host-side automation for PHC devices: Ansible playbooks/roles, bootstrap scripts, and systemd timers.
- Device tagging, mount UX, and service wrappers that consume platform-level ACL/DNS/Cloudflare/Entra decisions from **miket-infra**.
- Secrets consumption via `secrets-map.yml` + `secrets-sync` (AKV as SoR, `.env` as cache, 1Password for humans).

## Architecture & reference
- **Canonical architecture:** `docs/architecture/Miket_Infra_Devices_Architecture.md` (device roles, automation layers, platform boundary).
- **Platform context:** `docs/architecture/PHC_VNEXT_ARCHITECTURE.md` and component docs under `docs/architecture/components/` (Nextcloud, secrets).
- **Filesystem:** `docs/architecture/FILESYSTEM_ARCHITECTURE.md` (Flux/Space/Time v2.1 spec).
- **Reference:** `docs/reference/` for tailnet, account model, IaC/CaC details, secrets management.

## Operations
- **Runbooks:** `docs/runbooks/` (mounts, Nextcloud, backup/restore, device onboarding, secrets rotation).
- **Product/roadmap:** `docs/product/` for status, execution tracking, and team roles.
- **Communications:** `docs/communications/COMMUNICATION_LOG.md` for dated decisions; avoid new ad-hoc status files.

## Device inventory (summary)
- **motoko (server/core):** LiteLLM/Nextcloud host, PHC storage export, Ansible control node; ingress via Cloudflare Tunnel + Access only.
- **armitage (Fedora KDE / GPU / Ollama):** Fedora KDE workstation with NVIDIA GPU. Uses Ollama for LLM (per ADR-005 workstation pattern). Remote UX via NoMachine.
- **akira (Fedora / GPU / vLLM):** Fedora workstation (GNOME, migrating to KDE). vLLM server node with AMD GPU. Remote UX via NoMachine.
- **wintermute (Windows / GPU):** Windows workstation with vLLM, mapped Flux/Space/Time drives (X:/S:/T:), remote UX via NoMachine/WinRM.
- **count-zero & managed macOS:** Flux/Space/Time mounts at `~/{flux,space,time}` backed by `/~/.mkt`, OS cloud ingestion into `/space/devices/...`.

## Architecture references
- **ADR-004:** KDE Plasma is the standard desktop for all Linux UI nodes.
- **ADR-005:** Workstations use Ollama; servers use vLLM.

## Execution quick links
- Mount + device infrastructure deployment: `ansible/playbooks/deploy-devices-infrastructure.yml` (see `docs/runbooks/devices-infrastructure-deployment.md`).
- Secrets sync for services: `ansible/playbooks/secrets-sync.yml` (AKV → `.env`).
- Health validation: `ansible/playbooks/validate-mount-infrastructure.yml`.
