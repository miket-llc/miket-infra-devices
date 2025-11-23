# Data Lifecycle Specification (Flux / Time / Space)
**Status:** DRAFT
**Target:** miket-infra-devices (motoko)

## Overview

This specification defines the automation required to implement the Data Lifecycle Policy for the Flux/Time/Space storage architecture. It translates the high-level ontology into concrete systemd units, Rclone configurations, and Restic backup jobs running on `motoko`.

## 1. Cloud Backplane Dependencies (miket-infra)

Before implementation on `motoko`, the following resources must exist in the cloud (provisioned via Terraform in `miket-infra`):

### Azure Key Vault (`kv-miket-ops`)
- Secret: `b2-app-key-id` (B2 Key ID)
- Secret: `b2-app-key` (B2 Application Key)
- Secret: `restic-password` (Encryption password for Restic repos)

### Backblaze B2 Buckets
- `miket-space-mirror` (1:1 Mirror of `/space`)
    - Lifecycle: Keep only last version (Rclone sync handles deletion)
    - Encryption: Server-side (SSE-B2) preferred, or none if client-side encryption is too slow for browseability.
- `miket-backups-restic` (Versioning for `/flux` and `/space`)
    - Lifecycle: Keep all versions (Restic handles pruning)
    - Encryption: Client-side (Restic default)

## 2. Local Automation (miket-infra-devices)

These components will be deployed to `motoko` via Ansible.

### A. Flux Graduation (Local Policy)
**Goal:** Move cold data from high-speed storage to archival storage.

- **Script:** `/usr/local/bin/flux-graduate.sh`
- **Logic:**
    - Scan `/flux/active` for directories unmodified > 30 days.
    - EXCLUDE directories containing `.keep-local` marker file.
    - `rsync` move to `/space/projects/YYYY-Graduate/`.
    - Leave symlink in `/flux` (optional, maybe confusing?).
- **Schedule:** Nightly at 03:00.

### B. Flux Snapshots (Hourly Local)
**Goal:** Instant recovery of accidental deletions in the working set.

- **Tool:** Restic
- **Source:** `/flux`
- **Destination:** `/space/snapshots/flux-local` (Local repo on HDD)
- **Retention:** Keep 24 hourly, 7 daily.
- **Schedule:** Hourly (`*:00`).

### C. Space Mirror (Nightly Cloud)
**Goal:** Disaster recovery for the massive archive.

- **Tool:** Rclone
- **Source:** `/space`
- **Destination:** `b2:miket-space-mirror`
- **Mode:** `sync` (Mirror delete)
- **Flags:** `--fast-list --transfers 16 --track-renames`
- **Schedule:** Nightly at 04:00.

### D. Critical Backup (Daily Cloud)
**Goal:** Immutable, versioned history of the most critical data.

- **Tool:** Restic
- **Source:** `/flux` (Hot state)
- **Destination:** `b2:miket-backups-restic/flux`
- **Retention:** Keep 7 daily, 4 weekly, 12 monthly.
- **Schedule:** Daily at 05:00.

## 3. Directory Structure (Ontology)

This structure must be enforced by the Ansible role.

```text
/flux/
├── active/          # Syncthing hot-sets, active Git repos
├── scratch/         # Ephemeral downloads (auto-purge 7d)
├── models/          # Active LLM checkpoints (symlinked from space?)
└── .policy/         # Governance files

/space/
├── projects/        # Graduated projects (YYYY-Name)
├── media/           # Photos, Video
├── datasets/        # Static ML datasets
├── archives/        # Deep cold storage
└── snapshots/       # Local Restic repositories
    └── flux-local/
```

## 4. Implementation Plan

1.  **Cloud Provisioning**: Update `miket-infra` Terraform to create B2 buckets and keys.
2.  **Secret Management**: Populate `kv-miket-ops` with B2 credentials.
3.  **Ansible Role**: Create `data-lifecycle` role in `miket-infra-devices`.
    - Install Restic, Rclone.
    - Configure systemd timers.
    - Deploy graduation scripts.
4.  **Validation**: Verify data flows and restore paths.

