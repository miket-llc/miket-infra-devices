# Nextcloud Platform Contract

## Overview

This document defines the contract between the PHC Nextcloud platform (motoko), device clients (count-zero, etc.), and `/space` (System of Record). It establishes invariants that must never be violated by any tooling or automation.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PHC Nextcloud Platform                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐   │
│  │   motoko    │       │ count-zero  │       │   armitage  │   │
│  │   (server)  │       │   (macOS)   │       │  (Windows)  │   │
│  └──────┬──────┘       └──────┬──────┘       └──────┬──────┘   │
│         │                     │                     │          │
│         │                     │                     │          │
│    ┌────▼────┐          ┌─────▼─────┐         ┌────▼────┐      │
│    │ /space  │◄────────►│  ~/cloud  │◄───────►│  ~/nc   │      │
│    │  (SoR)  │   sync   │  (local)  │  sync   │ (local) │      │
│    └─────────┘          └───────────┘         └─────────┘      │
│         ▲                                                       │
│         │                                                       │
│         │                                                       │
│    ┌────┴────────────────────────────────────────────────┐     │
│    │              SYSTEM OF RECORD (SoR)                 │     │
│    │                                                     │     │
│    │  • Single source of truth for all data             │     │
│    │  • External storage backend for Nextcloud           │     │
│    │  • NEVER modified by device-side tooling           │     │
│    └─────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Invariants

### Invariant 1: /space is the System of Record (SoR)

- **Location:** `/space` on motoko
- **Role:** Single source of truth for all synchronized data
- **Protection:** No device-side tooling may directly modify `/space`

All changes flow through the Nextcloud sync mechanism:
1. Client modifies local copy (e.g., `~/cloud`)
2. Nextcloud client syncs change to server
3. Server writes to `/space` through external storage mount

### Invariant 2: /space Layout is Immutable

The directory structure of `/space` must never be altered by external tooling:

```
/space/
├── work/           # Work files
├── media/          # Media library
├── finance/        # Financial documents
├── inbox/          # Incoming files
├── assets/         # Shared assets
├── camera/         # Photo uploads
├── ms365/          # Microsoft 365 archive
└── Dashboard/      # Data Estate Status
```

**Violations:** Any script or automation that creates, moves, or deletes top-level directories under `/space` violates this invariant.

### Invariant 3: Device-Side Changes are Local Only

Device-side tooling (scripts, LaunchAgents, scheduled tasks) may only operate on:
- Local sync directories (e.g., `~/cloud`, `~/nc`)
- Device configuration files
- Local logs and caches

**Allowed:**
- ✅ Fix permissions in `~/cloud` on count-zero
- ✅ Create local backup of sync state
- ✅ Monitor local disk usage

**Prohibited:**
- ❌ SSH into motoko and modify `/space`
- ❌ Use SMB/NFS to directly access `/space`
- ❌ Bypass Nextcloud sync with direct file operations

---

## Device-Side Permissions Guard

### Purpose

macOS applications (notably Obsidian) sometimes create directories with overly restrictive permissions (`700` / `drwx------`). This blocks the Nextcloud client from reading those directories, causing sync failures (red error icon).

### Implementation

A device-local permissions guard runs on macOS clients:

| Component | Description |
|-----------|-------------|
| `fix-nextcloud-folder-permissions.sh` | Normalizes permissions (700→755, 600→644) |
| `monitor-nextcloud-permissions.sh` | Periodic scanner that invokes the fix script |
| LaunchAgent | Runs monitor every 15 minutes |

### Contract Compliance

The permissions guard is explicitly designed to comply with platform invariants:

1. **Operates on local sync directories only** (`~/cloud`)
2. **Never touches `/space`** - forbidden roots include `/space`, `/flux`
3. **Changes flow through Nextcloud** - permission changes sync to server via normal mechanism
4. **Managed via Ansible** - no manual configuration

### Safety Mechanisms

The fix script includes multiple safety checks:

```bash
FORBIDDEN_ROOTS=(
    "/"
    "/Users"
    "/var"
    "/etc"
    "/System"
    "/Library"
    "/private"
    "/space"    # Motoko SoR - NEVER touch
    "/flux"     # Motoko apps - NEVER touch
    "/Volumes"
)
```

If invoked with a forbidden path, the script exits with an error.

---

## Extension Guidelines

When adding new device-side tooling that interacts with Nextcloud sync:

### ✅ DO

1. **Operate on local paths only** - Use `~/cloud`, `~/nc`, or equivalent
2. **Follow IaC/CaC principles** - All tooling via Ansible, version controlled
3. **Include safety checks** - Validate paths before operations
4. **Log operations** - Write to local logs for debugging
5. **Be idempotent** - Safe to run multiple times

### ❌ DON'T

1. **Touch `/space` directly** - NEVER bypass Nextcloud sync
2. **Modify server configuration** - That's `nextcloud_server` role territory
3. **Create manual scheduled tasks** - Use Ansible-managed LaunchAgents/systemd
4. **Store secrets in scripts** - Use Azure Key Vault via secrets-sync

---

## Runbooks

| Scenario | Runbook |
|----------|---------|
| Red icon on folder | [nextcloud-permissions-troubleshooting.md](../runbooks/nextcloud-permissions-troubleshooting.md) |
| Connection issues | [troubleshoot-count-zero-nextcloud.md](../runbooks/troubleshoot-count-zero-nextcloud.md) |
| Server issues | [nextcloud_m365_sync.md](../runbooks/nextcloud_m365_sync.md) |

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-04 | Initial platform contract document | Codex |
| 2025-12-04 | Added device-side permissions guard specification | Codex |

