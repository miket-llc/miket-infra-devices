# Documentation

This tree holds the permanent, canonical documentation for **miket-infra-devices**. Architecture is singular and lives in the `docs/architecture/` folder with subordinate component docs. Reference, runbooks, product, and communications are organized so every topic has one home.

## Where to start
- **New contributors / PMs:** Read `docs/architecture/PHC_VNEXT_ARCHITECTURE.md` for the PHC big picture, then `docs/architecture/Miket_Infra_Devices_Architecture.md` for endpoint scope.
- **Operators:** Follow runbooks in `docs/runbooks/` and the secrets patterns in `docs/architecture/components/SECRETS_ARCHITECTURE.md`.
- **Storage/UX:** See `docs/architecture/FILESYSTEM_ARCHITECTURE.md` for Flux/Space/Time rules and `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md` for Nextcloud constraints.
- **Status/decisions:** `docs/product/STATUS.md`, `docs/product/EXECUTION_TRACKER.md`, and `docs/communications/COMMUNICATION_LOG.md`.

## Structure
- **`architecture/`** – Canonical design docs
  - `FILESYSTEM_ARCHITECTURE.md`
  - `PHC_VNEXT_ARCHITECTURE.md`
  - `Miket_Infra_Devices_Architecture.md`
  - `components/` (e.g., `NEXTCLOUD_PHC_ARCHITECTURE.md`, `SECRETS_ARCHITECTURE.md`)
- **`reference/`** – Detailed specs and decision support (account model, tailnet, IaC/CaC, space-mirror review)
- **`runbooks/`** – Operational procedures and troubleshooting
- **`product/`** – Roadmaps, status, execution tracking, team structure
- **`communications/`** – COMMUNICATION_LOG and coordination records
- **`archive/`** – Historical content kept for context (superseded by canonical docs)
- **`guides/` / `initiatives/` / `migration/`** – Deep dives and project documentation linked from the canonical architecture

## Standards
1. **Single source of truth** – Architecture lives once; other docs must reference it.
2. **No ephemeral docs** – Point-in-time notes belong in `docs/communications/COMMUNICATION_LOG.md`.
3. **Secrets discipline** – AKV is SoR; `.env` caches come from `secrets-sync`; 1Password is human-only.
4. **IaC/CaC first** – Prefer Terraform/Terragrunt + Ansible over ad-hoc scripts; document changes alongside code.

Use `docs/product/TEAM_ROLES.md` for full documentation protocols and ownership.
