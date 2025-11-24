---
document_title: "Data Reconciliation Prompt - Multi-Source Transfer Merge"
author: "Codex-CA-001"
last_updated: 2025-11-24
status: Draft
related_initiatives:
  - initiatives/onedrive-to-space-migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# Data Reconciliation Prompt - Multi-Source Transfer Merge

## Context

You are working inside the MikeT LLC Personal Hybrid Cloud (PHC) ecosystem.

**Repos:**
- `miket-infra` = Terraform/Terragrunt for Entra, Cloudflare, storage, monitoring, and PHC services.
- `miket-infra-devices` = Ansible for motoko, wintermute, armitage, count-zero, and other endpoints.

## Core Invariants (DO NOT VIOLATE)

### 1) Storage & Filesystem
- `/space` = System of Record (SoR) for files.
- `/flux` = runtime surface (apps, DBs, models, caches) – no long-term human docs.
- `/time` = Time Machine target.
- `motoko` is the anchor fileserver exposing SMB shares:
  - `\\motoko\space`, `\\motoko\flux`, `\\motoko\time`.
- M365 (Teams/SharePoint/OneDrive Business) is a collaboration surface, never the primary SoR.
- OS clouds (iCloud, OneDrive personal/business, etc.) are "playgrounds" captured via one-way ingestion:
  - Client → `/space/devices/<hostname>/<username>/*` only; never sync back.
- No circular sync loops involving `/space`, `/flux`, M365, or OS clouds.

### 2) Identity, Network, PHC & AI Fabric
- Entra ID is the primary IdP for everything: devices, Cloudflare Access, Tailscale, PHC services.
- Tailscale provides the private mesh and SSH; Cloudflare Access optionally fronts any public ingress.
- Flux/Space/Time on motoko is the storage backplane, mirrored to Backblaze B2 via restic/rclone.
- LiteLLM on motoko is the single OpenAI-compatible AI gateway, federating GPU nodes (vLLM on armitage/wintermute) and cloud LLMs.
- Do NOT propose new random stacks; extend the existing PHC vNext architecture and patterns.

### 3) Secrets Architecture
- Azure Key Vault (AKV) is the **system of record** for automation secrets.
- 1Password is for humans only (logins, recovery, break-glass), never for headless automation.
- Local `.env` files on hosts are **ephemeral caches** generated from AKV (via Ansible/script), stored under `/flux/runtime/secrets/*.env`, `0600` permissions.
- No new Ansible Vault blobs for automation secrets; migrate/align with AKV + `.env` patterns.
- Config files must reference env vars / placeholders, not raw secret values.

### 4) Documentation & Governance (both repos)
When you create or modify anything, you must:
- Use the docs taxonomy:
  - `docs/initiatives/` – end-to-end initiative packages
  - `docs/reference/` – durable architecture and controls
  - `docs/guides/` – troubleshooting how-tos
  - `docs/runbooks/` – operational playbooks
  - `docs/reports/` – status & executive views
  - `docs/product/` – roadmap, roles, trackers
  - `docs/communications/` – comms and decision logs
  - `docs/architecture/` – ADRs and guardrails
- Put **mandatory front matter** on every doc (at minimum):
  - `document_title`, `author`, `last_updated`, `status`, `related_initiatives`, `linked_communications`.
- Never add "ephemeral" Markdown in the repo root; file everything into the proper taxonomy.
- Prefer **consolidation**: merge related docs into initiative packages; link instead of duplicating.

### 5) Roadmaps, Versioning & Tracking
- Use semantic versioning for architectures/modules: `Major.Minor.Patch`.
- Single source of truth for architecture version is in `README.md`.
- Update version in:
  - `README.md`,
  - relevant deliverable summaries,
  - any Makefile/comments that carry version labels.
- Maintain:
  - `docs/product/Vx_y_ROADMAP.md` with:
    - Executive overview, Completed, OKRs, wave planning, release criteria, governance.
  - `docs/product/EXECUTION_TRACKER.md` with:
    - Agent/persona status, latest outputs, next check-ins.
  - `docs/product/DAY0_BACKLOG.md` with:
    - Task IDs, owners, dependencies, notes.
  - `docs/communications/COMMUNICATION_LOG.md` with:
    - Dated entries, anchor links, and references to affected artifacts.

### 6) Multi-Persona Execution Protocol
- Assume a multi-persona model:
  - Chief Architect proxies the team (DevOps, IaC, Security, SRE, Networking, Release, FinOps, DocOps, UX/DX).
  - Never assume; verify by reading existing docs, modules, and PRs before acting.
  - Always perform implicit tasks (tests, docs, communication log updates, tracker updates) even if not explicitly requested.
  - Do full end-to-end testing before marking work as complete.
- Product Manager is responsible for:
  - Version bumps (Major/Minor/Patch),
  - Roadmap updates and wave sequencing,
  - Ensuring EXECUTION_TRACKER, backlog, and comms are up to date.

### 7) Alignment Between `miket-infra` and `miket-infra-devices`
- `miket-infra` defines platform/PHC capabilities and identity/network/storage.
- `miket-infra-devices` defines device config, mounts, ingestion jobs, NoMachine/Tailscale access, and UX.
- Any roadmap, feature, or change you propose for devices MUST:
  - Respect Flux/Space/Time invariants (no cloud sync directly on SMB mounts).
  - Call out dependencies on platform capabilities (Entra, Tailscale, storage, monitoring).
  - Fit into the docs/product roadmap + trackers described above.

When answering, planning, or generating code:
- Extend the existing architecture; do not introduce conflicting paradigms.
- Keep solutions maintainable by a single part-time founder.
- Prefer fewer, well-documented moving parts over experimental complexity.
- Always indicate where in the repo your proposed changes live and how they affect roadmap, trackers, and communication logs.

---

## Task: Reconcile Multi-Source Data Transfers

### Problem Statement

Multiple parallel data transfers have been executed from various sources to `/space`, resulting in fragmented, overlapping, and potentially duplicate data across multiple locations. You must design and execute a robust reconciliation strategy to merge all these "shards of broken glass" back into a coherent, deduplicated mirror in `/space`.

### Transfer Sources & Destinations

**From count-zero (macOS):**
1. `/Users/miket/dev/` → `/space/mike/dev/` (170 GB, ~43% complete)
2. `/Users/miket/Archives/` → `/space/mike/archives/` (86 GB, ~82% complete)
3. `/Users/miket/Library/CloudStorage/OneDrive-MikeTLLC/_MAIN_FILES/` → `/space/mike/_MAIN_FILES/` (4 GB, complete)
4. `/Users/miket/Library/Mobile Documents/com~apple~CloudDocs/` → `/space/devices/count-zero/icloud/` (5.8 GB, partial - cloud-only files skipped)
5. `/Users/miket/Downloads/` → `/space/devices/count-zero/downloads/` (58 GB, TCC-blocked, needs manual transfer)

**From M365 Cloud (rclone direct):**
6. `m365-mike:` → `/space/mike/_MAIN_FILES/` (overlaps with #3, ~4 GB, complete)

**From wintermute (Windows):**
7. `C:\\Users\\mdt_\` → `/space/inbox/wintermute-mdt_/` (890 GB, in progress)

**Additional Sources (not yet transferred):**
8. `mdt_@msn.com` personal OneDrive (cloud)
9. `MikeT LLC` business OneDrive (cloud)
10. iCloud Drive (cloud, partially captured)

### Current State Analysis Required

1. **Inventory all transfer destinations:**
   - Map every file location in `/space` from all transfers
   - Identify overlaps, duplicates, and conflicts
   - Document partial transfers and missing data

2. **File integrity verification:**
   - Compare checksums where available
   - Identify corrupted or incomplete files
   - Document any "Resource deadlock avoided" errors that may have caused data loss

3. **Metadata preservation:**
   - Timestamps (creation, modification, access)
   - Permissions (where applicable)
   - Extended attributes (macOS resource forks, Windows alternate data streams)

4. **Conflict resolution strategy:**
   - Same file from multiple sources (which version wins?)
   - Same path with different content (merge vs. rename?)
   - Cloud-only placeholders vs. local files

### Reconciliation Strategy Requirements

**You must design a reconciliation process that:**

1. **Deduplicates intelligently:**
   - Identifies true duplicates (same content, different paths)
   - Identifies version conflicts (same path, different content/timestamps)
   - Preserves the "best" version based on:
     - Most recent modification time
     - Most complete file (size, checksum validation)
     - Source priority (local > cloud, SoR > playground)

2. **Merges directory structures:**
   - Combines overlapping directory trees
   - Resolves path conflicts (e.g., `_MAIN_FILES` from local vs. cloud)
   - Creates canonical structure per PHC invariants:
     - `/space/mike/` - user data
     - `/space/devices/<hostname>/<username>/` - device-specific captures
     - `/space/inbox/` - staging for reconciliation

   **Canonical roles (keep only intended duplicates):**
   - **Primary work/assets/art:** `/space/mike/` (single canonical copy; conflict backups stay in run folders until curated).
   - **Archives:** `/space/mike/archives/` (read-mostly; duplicates allowed only as part of archive sets).
   - **Camera/field captures:** `/space/devices/<host>/<user>/camera/` raw → `/space/mike/assets/camera/` or `/space/mike/art/` after curation (one promoted copy).
   - **Device playgrounds:** `/space/devices/<host>/<user>/` for OS-cloud/download evidence; do not co-mingle with `/space/mike` until reviewed.
   - **Backups/snapshots:** `/space/journal/**`, `/space/inbox/reconciliation/runs/<id>/conflicts`, `/space/archive/reconciliation/<id>/` are the only long-lived duplicate locations.
   - **Forbidden:** New duplicate working trees under `/space/mike` or `/space/devices` outside these roles; route anything uncertain to `conflicts/` for human sort.

3. **Handles edge cases:**
   - Cloud-only placeholders (0-byte files that couldn't be downloaded)
   - TCC-blocked directories (macOS privacy restrictions)
   - OneDrive filesystem corruption artifacts
   - Partial transfers (interrupted rsync/robocopy)

4. **Preserves data integrity:**
   - Validates checksums before/after merge
   - Creates reconciliation logs
   - Maintains audit trail of all decisions
   - Provides rollback capability

5. **Uses AI in assist-only mode:**
   - LiteLLM may summarize manifests or flag likely duplicates for human review.
   - All copy/merge actions remain deterministic shell tooling; AI outputs are never applied automatically.

6. **Optimizes for maintainability:**
   - Single script/playbook that can be re-run idempotently
   - Clear logging and progress reporting
   - Error handling with graceful degradation
   - Documentation of all decisions and edge cases

### Deliverables

1. **Reconciliation Script/Playbook:**
   - Location: `scripts/reconcile-multi-source-transfers.sh` or `ansible/playbooks/reconcile-data-transfers.yml`
   - Must be idempotent and resumable
   - Must produce detailed logs

2. **Updated Migration Documentation:**
   - Capture reconciliation guardrails in `MIGRATION_PLAN.md`
   - Log execution details in `COMMUNICATION_LOG.md`

### Success Criteria

- [ ] All source data accounted for in final `/space` structure
- [ ] No data loss (all files from all sources present in final structure)
- [ ] Duplicates identified and resolved (either merged or archived)
- [ ] Conflicts resolved with documented rationale
- [ ] Final structure complies with PHC invariants
- [ ] Verification report confirms integrity
- [ ] Reconciliation process is documented and repeatable
- [ ] All documentation updated per governance requirements

### Constraints

- Must not violate PHC invariants (especially no circular syncs)
- Must preserve `/space` as SoR (no sync back to clouds)
- Must be maintainable by single part-time founder
- Must handle TB-scale data efficiently
- Must provide clear audit trail

### Questions to Answer

1. What is the canonical directory structure for merged data?
2. How do we handle the `_MAIN_FILES` overlap (local vs. M365 cloud)?
3. What happens to the `wintermute-mdt_` inbox folder after reconciliation?
4. How do we handle cloud-only placeholders that couldn't be downloaded?
5. What's the priority order for conflict resolution (local > cloud > oldest)?
6. Should we create a `/space/archive/` for old/duplicate versions?
7. How do we verify completeness without re-scanning all sources?

---

**Begin by:**
1. Reading existing migration documentation
2. Analyzing current `/space` structure
3. Creating inventory of all transfer destinations
4. Designing reconciliation algorithm
5. Implementing and testing reconciliation process
6. Documenting all decisions and outcomes
