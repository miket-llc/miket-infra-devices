# Podman Cleanup Role

Safely removes unused Podman resources to free disk space on motoko and other Podman hosts.

## Purpose

This role cleans up unused Podman containers, images, volumes, networks, and build cache to recover disk space. It's designed to be run periodically or when disk space alerts are triggered.

## Usage

### Basic Cleanup

```yaml
- hosts: motoko
  roles:
    - role: podman_cleanup
      vars:
        podman_cleanup_confirm: true
```

### Aggressive Cleanup (All Unused Resources)

```yaml
- hosts: motoko
  roles:
    - role: podman_cleanup
      vars:
        podman_cleanup_confirm: true
        podman_cleanup_prune_all: true
```

### Selective Cleanup

```yaml
- hosts: motoko
  roles:
    - role: podman_cleanup
      vars:
        podman_cleanup_confirm: true
        podman_cleanup_remove_stopped_containers: true
        podman_cleanup_remove_unused_images: true
        podman_cleanup_remove_unused_volumes: false  # Keep volumes
        podman_cleanup_remove_unused_networks: true
        podman_cleanup_remove_build_cache: true
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `podman_cleanup_confirm` | `false` | **Required:** Must be `true` to perform cleanup |
| `podman_cleanup_remove_stopped_containers` | `true` | Remove stopped containers |
| `podman_cleanup_remove_unused_images` | `true` | Remove unused images |
| `podman_cleanup_remove_unused_volumes` | `false` | Remove unused volumes (keep by default) |
| `podman_cleanup_remove_unused_networks` | `true` | Remove unused networks |
| `podman_cleanup_remove_build_cache` | `true` | Remove build cache |
| `podman_cleanup_prune_all` | `false` | Remove all unused resources (more aggressive) |
| `podman_cleanup_prune_until` | `""` | Optional: prune resources older than this (e.g., "24h", "7d") |

## Safety

- Requires explicit confirmation (`podman_cleanup_confirm: true`)
- Does not remove volumes by default (may contain data)
- Shows before/after disk usage and Podman resource usage
- Safe to run on production systems (only removes unused resources)

## Tags

- `podman_cleanup` - All cleanup tasks
- `safety` - Safety checks
- `check` - Pre-flight checks

## Example Output

```
Podman usage before cleanup:
TYPE            TOTAL      ACTIVE    SIZE      RECLAIMABLE
Images          15         3         2.5GB     1.8GB (72%)
Containers      8          2         500MB      300MB (60%)
Local Volumes   5          3         200MB     50MB (25%)
Build Cache     2          0         100MB     100MB (100%)

Disk usage after cleanup:
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  20G   15G  4.5G  77%  /
```

