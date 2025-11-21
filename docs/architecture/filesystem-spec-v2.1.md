# Filesystem Architecture Specification v2.1

**Status:** ACTIVE
**Version:** 2.1
**Supersedes:** v2.0, Architecture Handoff Flux
**Owner:** Chief Device Architect

## 1. Core Philosophy

The Miket-Infra filesystem is ontology-driven, not implementation-driven. We define three semantic pillars that persist across all devices and platforms.

### The Three Pillars

| Pillar | Path (UX) | Purpose | Characteristics |
|:--- |:--- |:--- |:--- |
| **Flux** | `~/flux` | **High-Energy State.** Active projects, code, WIP. | Fast, hot, local snapshots. |
| **Space** | `~/space` | **The Infinite.** Archives, media, datasets, cloud mirrors. | Vast, slow, reliable. |
| **Time** | `~/time` | **History.** Backups, time-travel. | Read-mostly, recovery. |

## 2. Implementation Standards

### 2.1. Mount Points

To ensure multi-user safety and permission isolation, we use **user-level implementation paths** masked by **canonical user-facing symlinks**.

**macOS:**
- **Implementation:** `~/.mkt/{flux,space,time}` (User-owned mount points)
- **User Interface:** `~/{flux,space,time}` (Symlinks to implementation)
- **Protocol:** SMB via `//motoko/{flux,space,time}`

**Windows:**
- **Implementation:** Network Drives (Mapped per session)
- **User Interface:**
  - `X:` (Flux)
  - `S:` (Space)
  - `T:` (Time)
- **Protocol:** SMB via `\\motoko\{flux,space,time}`

**Linux:**
- **Implementation:** `/mnt/{flux,space,time}` (System mounts) OR `~/.mkt/...` (FUSE/GVFS if unprivileged)
- **User Interface:** `~/{flux,space,time}` (Symlinks)
- **Protocol:** SMB/NFS via `//motoko/{flux,space,time}`

### 2.2. Network Resolution

- **Primary Target:** `motoko` (Hostname via Tailscale MagicDNS or Local DNS)
- **Fallback:** IP Address (Discouraged, config-driven only)
- **Constraint:** All device automation MUST attempt hostname resolution first.

## 3. Device Health & Observability

Devices must report their health state back to the central storage (`/space/devices`) to ensure visibility without active polling from the server.

### 3.1. Health Manifest

Each managed device writes a status file upon successful mount/sync operations:

**Path:** `/space/devices/<hostname>/<username>/_status.json`

**Schema:**
```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "device": "count-zero",
  "user": "miket",
  "platform": "macOS",
  "status": "healthy", // or "degraded", "error"
  "components": {
    "mounts": {
      "flux": true,
      "space": true,
      "time": true
    },
    "os_cloud_sync": {
      "last_run": "2025-01-01T10:00:00Z",
      "status": "success"
    }
  }
}
```

## 4. OS Cloud Ingestion

We treat OS-native clouds (iCloud, OneDrive) as **ingest sources**, not primary storage.

- **Flow:** Device `-->` Sync Agent `-->` `/space/devices/<host>/<user>/...`
- **Loop Prevention:**
  - macOS: `rsync --no-links` + Explicit excludes (`~/flux`, `~/space`).
  - Windows: `robocopy /XJ` + Explicit excludes (Junctions, mapped drives).
  - **Rule:** NEVER sync the mount points themselves back to the cloud.

## 5. Migration Notes (v2.0 -> v2.1)

- **Deprecated:** System-level `/mkt` mounts on macOS are no longer the standard.
- **Deprecated:** Hardcoded IP addresses in mount scripts.
- **New:** Mandatory `_status.json` reporting.


