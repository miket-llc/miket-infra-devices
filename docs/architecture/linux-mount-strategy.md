# Linux Mount Strategy

**Status:** ACTIVE  
**Last Updated:** 2024-12-02  
**Owner:** Infrastructure Team

## Overview

This document describes the mount strategy for Linux devices in the fleet. The strategy was revised after the **2024-12-01 incident** where a CIFS kernel bug caused atom's desktop to freeze.

## The Incident (2024-12-01)

### What Happened

1. atom (resilience node) had static CIFS mounts in `/etc/fstab` to motoko's shares
2. A network hiccup caused the CIFS kernel module to invalidate its directory cache
3. The `cfids_invalidation_worker` function hit a kernel bug: "scheduling while atomic"
4. This cascaded to dbus failures (services couldn't activate)
5. GNOME Shell froze - mouse moved but UI was unresponsive
6. Recovery required SSH restart of GDM

### Root Cause

The CIFS kernel module has a known bug where cache invalidation can cause kernel instability if called in the wrong context. Static mounts keep the CIFS module actively engaged with the server, so any network hiccup can trigger the bug.

### Lesson Learned

**Static CIFS mounts in fstab are dangerous on Linux desktops.** Kernel-level bugs can take down the entire userspace.

## Mount Strategy by Device Type

| Device Type | Mount Method | Rationale |
|-------------|--------------|-----------|
| **Resilience Nodes** (atom) | **None** | Zero dependencies on other servers |
| **Linux Workstations** | **autofs** | On-demand mounting, graceful timeout |
| **Servers** (motoko) | **Bind mounts** | It's the source of the shares |
| **Windows** | Native SMB | Different client implementation |
| **macOS** | mount_smbfs | Different client implementation |

## Resilience Nodes: No Mounts

Resilience nodes like atom exist to **stay alive when everything else is down**. They should have zero dependencies on other servers being reachable.

### What Resilience Nodes Need
- ✅ node_exporter (Prometheus metrics)
- ✅ SSH access (Tailscale)
- ✅ Battery (implicit UPS)

### What Resilience Nodes Do NOT Need
- ❌ CIFS mounts to motoko
- ❌ Continuous file access
- ❌ Any service that depends on another server

### Health Reporting

Resilience nodes push health status via SSH instead of writing to mounted shares:

```bash
# SSH-based push (doesn't require local mounts)
ssh motoko.pangolin-vega.ts.net "cat > /space/devices/atom/mdt/_status.json" <<< "$JSON"
```

If motoko is unreachable, the health push fails silently. **This is expected and correct** - the resilience node keeps working regardless.

## Linux Workstations: Autofs

For Linux workstations that need file access, use the `mount_shares_linux_autofs` role.

### Why Autofs?

| Feature | Static fstab | Autofs |
|---------|--------------|--------|
| Mount on boot | Yes | No (on-demand) |
| Unmount on idle | No | Yes |
| Hang on server down | Yes (system freeze) | No (timeout) |
| CIFS kernel bug exposure | High | Low |

### How It Works

1. User accesses `~/flux` (symlink to `/mnt/motoko/flux`)
2. Autofs detects access and mounts the share
3. User works with files
4. After 5 minutes idle, autofs unmounts the share
5. If server is unreachable, mount times out gracefully (30s)

### Configuration

```yaml
# In playbook for Linux workstations
- hosts: linux_workstations
  roles:
    - role: mount_shares_linux_autofs
      vars:
        smb_password: "{{ lookup('pipe', 'az keyvault secret show ...') }}"
        autofs_timeout: 300  # 5 minutes
```

### Mount Options

The autofs map uses safe mount options:

```
-fstype=cifs,credentials=...,soft,timeo=30
```

- `soft`: Operations timeout instead of hanging forever
- `timeo=30`: 30-second timeout on operations

## Implementation

### For atom (already done)

```bash
# Remove existing CIFS mounts
ansible-playbook -i inventory/hosts.yml playbooks/atom/remove-cifs-mounts.yml
```

### For new Linux workstations

```yaml
# In the workstation's playbook
- role: mount_shares_linux_autofs
  tags: [mounts, shares, storage]
```

### Do NOT use mount_shares_linux role

The original `mount_shares_linux` role uses static fstab mounts. It's preserved for reference but **should not be used for desktop systems**.

## Affected Files

| File | Change |
|------|--------|
| `playbooks/atom/site.yml` | Removed mount_shares_linux role |
| `playbooks/atom/remove-cifs-mounts.yml` | New playbook to clean up mounts |
| `host_vars/atom.yml` | Removed SMB configuration |
| `roles/mount_shares_linux_autofs/` | New role for safe autofs mounting |

## References

- [CIFS kernel bug reports](https://bugzilla.kernel.org/) - search for "cfids_invalidation_worker"
- [Autofs documentation](https://wiki.archlinux.org/title/Autofs)
- Incident log: atom desktop freeze 2024-12-01 21:43 UTC

