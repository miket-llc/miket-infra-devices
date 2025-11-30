# Docker Cleanup Linux Role

**Version:** 1.0  
**Purpose:** Remove Docker installations from Linux hosts to prevent conflicts with Podman standard

---

## Overview

This role safely removes Docker (docker-ce, moby-engine, docker.io) from Linux hosts to comply with the container runtime standard.

**Use with caution:** This will stop and remove all Docker containers.

---

## Usage

```yaml
- name: Remove Docker before Podman migration
  hosts: linux_servers
  roles:
    - role: docker_cleanup_linux
      vars:
        docker_cleanup_export_containers: true  # Export before removing
        docker_cleanup_confirm: true            # Safety check
```

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `docker_cleanup_export_containers` | `true` | Export containers before removal |
| `docker_cleanup_backup_path` | `/root/docker-backup` | Container export location |
| `docker_cleanup_confirm` | `false` | Must be `true` to actually remove |
| `docker_cleanup_remove_images` | `true` | Remove Docker images |
| `docker_cleanup_remove_volumes` | `false` | Remove Docker volumes (data loss!) |

---

## Safety Features

- Requires explicit confirmation (`docker_cleanup_confirm: true`)
- Exports containers by default
- Creates backup before removal
- Logs all actions
- Can preserve volumes by default

---

## Example Playbook

```yaml
---
- name: Migrate from Docker to Podman
  hosts: target_host
  become: true
  
  tasks:
    - name: Export and remove Docker
      ansible.builtin.include_role:
        name: docker_cleanup_linux
      vars:
        docker_cleanup_confirm: true
        docker_cleanup_export_containers: true
        docker_cleanup_remove_volumes: false  # Keep data
    
    - name: Install Podman standard
      ansible.builtin.include_role:
        name: podman_standard_linux
```

---

## Related Documentation

- [Container Runtime Standard](../../../docs/CONTAINERS_RUNTIME_STANDARD.md)

