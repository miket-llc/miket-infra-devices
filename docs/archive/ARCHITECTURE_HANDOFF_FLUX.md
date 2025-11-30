# Architecture Handoff: Flux, Time, and Space
**Status:** ARCHIVED - Superseded by canonical architecture
**Date Archived:** 2025-12-01
**Canonical Reference:** `docs/architecture/FILESYSTEM_ARCHITECTURE.md`

> **Note:** This document is archived for historical reference. The canonical filesystem architecture is now defined in `docs/architecture/FILESYSTEM_ARCHITECTURE.md` (v2.1). All implementation details and operational procedures should reference that document.

---

**Original Content (for historical reference):**

# Architecture Handoff: Flux, Time, and Space
**Status:** IMPLEMENTED
**To:** Architecture Team (The Visionaries)
**From:** Infrastructure Team (The Builders)

## Executive Summary

We have successfully deployed a high-performance, ontology-driven storage architecture on `motoko` that supersedes the initial draft design. The system is live, formatted, and automated.

**CRITICAL CORRECTION:** The concept of `_MAIN_FILES` is deprecated. It implies a static, monolithic file dump. We have moved to a dynamic ontology based on **Flux** (working state), **Time** (history/backup), and **Space** (archival/infinite).

## The Implemented Architecture

### 1. The Pillars (Mount Points)

We have rejected the standard `/Volumes` or `/mnt` obscurity in favor of top-level, semantic mount points on `motoko`. This is not just a drive mapping; it is a philosophy.

| Concept | Mount Point | Device | Usage | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Flux** | `/flux` | LaCie 4TB (SSD/HDD) | **High-Energy State.** This is the hot working directory. Local clones of git repos, active databases, Docker volumes, LLM models being fine-tuned. It flows and changes constantly. | ✅ Active |
| **Time** | `/time` | WD 8TB Partition | **History.** Dedicated Time Machine backing store. Optimized with Samba `vfs_fruit` for native macOS backup performance. It looks backward. | ✅ Active |
| **Space** | `/space` | WD 12TB Partition | **The Infinite.** Archival storage, large datasets, media, backups of the Flux state. It is vast and static. It looks outward (to the cloud). | ✅ Active |

### 2. The Network Fabric

We are not "manually sharing" drives. We have built an **Automated Infrastructure**.

*   **Protocol**: SMB (Samba 4.x) with macOS extensions enabled (`AAP` extensions, `catia`, `fruit`, `streams_xattr`).
*   **Security**:
    *   Authentication via `motoko` system users.
    *   Passwords managed in **Azure Key Vault** (`kv-miket-ops`) and **1Password**.
    *   **No hardcoded credentials** in scripts or code.
*   **Clients**:
    *   **macOS (`count-zero`)**: Custom Ansible role deploys a persistent `LaunchAgent`. On login, it securely fetches the SMB password from Azure Key Vault and mounts to `~/.mkt/flux`, `~/.mkt/space`, `~/.mkt/time`, with user symlinks `~/flux`, `~/space`, `~/time`.
    *   **Windows (`armitage`, `wintermute`)**: Custom Ansible role maps `X:` (Flux), `S:` (Space), and `T:` (Time) as native network drives with proper labels.

### 3. Corrections to the Draft Design

The "Shitty Diagram" (your words) had good intentions but missed the implementation reality. Here is the diff:

*   **❌ Drop `_MAIN_FILES`**: Do not create a folder called `_MAIN_FILES`. It's ugly and vestigial.
    *   **✅ Use `/space`**: This *is* your authoritative mirror. It is the root of the "Space" ontology.
*   **❌ "Option A vs Option B" for Time Machine**: We chose **Option C (The Enterprise Way)**.
    *   We didn't just "plug it in." We configured Samba with `fruit:time machine = yes` and dedicated capacity limits. It advertises itself as a Time Machine target natively to the network. No manual hacks required.
*   **❌ "Launchd scripts for B2"**: Too low level.
    *   **✅ Future State**: We should use **Restic** or **Rclone** via systemd timers on `motoko`, backing up `/flux` (hot) and `/space` (cold) to B2.

## The New "Truth" Diagram

```mermaid
graph TD
    subgraph Cloud
        B2[(Backblaze B2)]
    end

    subgraph Motoko [Motoko (The Anchor)]
        Flux[/"/flux (Hot State)"/]
        Space[/"/space (Archival)"/]
        Time[/"/time (History)"/]
        
        Flux -->|Nightly Snapshot| Space
        Space -->|Rclone Sync| B2
        Time -->|Time Machine Protocol| MacClients
    end

    subgraph Clients
        CountZero[Count-Zero (macOS)]
        Wintermute[Wintermute (Win/AI)]
        Armitage[Armitage (Win/Gaming)]
    end

    %% Connections
    CountZero -- "Auto-Mount (SMB)" --> Flux & Space & Time
    Wintermute -- "Drive S: / F: (SMB)" --> Flux & Space
    Armitage -- "Drive S: / F: (SMB)" --> Flux & Space

    style Flux fill:#ff9900,stroke:#333,stroke-width:2px
    style Space fill:#0099ff,stroke:#333,stroke-width:2px
    style Time fill:#99cc00,stroke:#333,stroke-width:2px
```

## Action Items for Architecture Team

Your job is now to build *on top* of this foundation. Do not re-litigate the mounts. They are done.

**Your Prompt to the Engineer (Me):**

> "The storage layer is solved. We have `/flux`, `/space`, and `/time` mounted and accessible everywhere.
>
> Now, design the **Data Lifecycle Policy**:
> 1.  How do we automate the backup of `/flux` to `/space`? (Restic? Rsync?)
> 2.  How do we sync `/space` to Backblaze B2 effectively (handling the 12TB scale)?
> 3.  Define the directory structure *inside* `/flux` and `/space` (e.g., `/space/projects`, `/space/media`, `/flux/active-dev`).
> 4.  How does Syncthing fit in for 'hot-sets' inside `/flux`?"

**Signed,**
*The Chief Architect (Implementation Division)*

