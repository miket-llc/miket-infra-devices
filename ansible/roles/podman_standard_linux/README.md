# Podman Standard Linux Role

**Version:** 2.0  
**Status:** Active  
**Supports:** Fedora, Ubuntu, Debian, RHEL, CentOS, and other major Linux distributions

---

## Overview

This role implements the **official container runtime standard** for all Linux hosts in the miket-infra-devices ecosystem.

**Key Features:**
- Installs Podman as the primary container runtime
- Provides Docker CLI compatibility (`docker` commands map to `podman`)
- Configures container registries (docker.io, quay.io, ghcr.io)
- Supports rootless containers (secure by default)
- Integrates with systemd for service management
- Optional NVIDIA GPU support via NVIDIA Container Toolkit
- Custom storage paths for dedicated container drives

---

## Usage

### Basic Usage

```yaml
- name: Install Podman standard runtime
  hosts: linux_servers
  roles:
    - role: podman_standard_linux
```

### With Custom Storage (e.g., motoko)

```yaml
- name: Install Podman with custom storage
  hosts: motoko
  roles:
    - role: podman_standard_linux
      vars:
        podman_graphroot: /space/containers/engine/podman
        podman_runroot: /run/containers/storage
        podman_nvidia_enabled: true
```

### Workstation Usage

```yaml
- name: Install Podman on workstation
  hosts: linux_workstations
  roles:
    - role: podman_standard_linux
      vars:
        podman_install_cockpit: false  # No GUI on headless
```

---

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `podman_install_docker_compat` | `true` | Install Docker CLI compatibility layer |
| `podman_install_cockpit` | `false` | Install cockpit-podman web UI (Fedora only) |
| `podman_user` | `mdt` | User for rootless container configuration |
| `podman_enable_linger` | `true` | Enable user lingering (containers survive logout) |
| `podman_enable_socket` | `true` | Enable Podman API socket |

### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `podman_storage_driver` | `overlay` | Storage driver (overlay recommended) |
| `podman_graphroot` | `""` | Custom image/layer storage path (empty = default) |
| `podman_runroot` | `""` | Custom runtime data path (empty = default) |
| `podman_configure_storage` | `true` | Enable custom storage configuration |
| `podman_create_storage_dirs` | `true` | Auto-create storage directories |

### Registry Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `podman_registries_search` | `[docker.io, quay.io, ghcr.io]` | Unqualified image search registries |

### NVIDIA GPU Support

| Variable | Default | Description |
|----------|---------|-------------|
| `podman_nvidia_enabled` | `true` | Install NVIDIA Container Toolkit (if GPU detected) |

---

## Package Lists

### Fedora/RHEL/CentOS

- `podman` - Container runtime
- `podman-compose` - Docker Compose compatibility
- `buildah` - Container build tool
- `skopeo` - Container image operations
- `podman-docker` - Docker CLI compatibility (optional)
- `cockpit-podman` - Web UI (optional)

### Ubuntu/Debian

- `podman` - Container runtime
- `buildah` - Container build tool
- `skopeo` - Container image operations
- `python3-pip` - For podman-compose installation
- Docker CLI wrapper created at `/usr/local/bin/docker`
- Docker Compose wrapper created at `/usr/local/bin/docker-compose`

---

## Docker CLI Compatibility

### How It Works

**Fedora/RHEL:**
- `podman-docker` package provides `/usr/bin/docker` → `podman` symlink
- All `docker` commands transparently map to Podman

**Ubuntu/Debian:**
- Custom wrapper script created at `/usr/local/bin/docker`
- Wrapper executes `podman` with same arguments

**Result:**
```bash
# All these commands work and map to Podman:
docker ps
docker run nginx:latest
docker build -t myapp .
docker-compose up -d
```

---

## Storage Configuration

### Default Storage Paths

- **Root containers:** `/var/lib/containers/storage`
- **Rootless containers:** `~/.local/share/containers/storage`
- **Runtime data:** `/run/containers/storage`

### Custom Storage (motoko Example)

```yaml
podman_graphroot: /space/containers/engine/podman
podman_runroot: /run/containers/storage
```

Configured via: `/etc/containers/storage.conf.d/00-custom-storage.conf`

---

## Tags

| Tag | Purpose |
|-----|---------|
| `podman_standard` | All tasks in this role |
| `containers` | Container-related tasks |
| `install` | Package installation |
| `config` | Configuration tasks |
| `storage` | Storage configuration |
| `verify` | Verification tasks |
| `nvidia` | NVIDIA GPU support |
| `rootless` | Rootless configuration |

**Usage:**
```bash
# Install only
ansible-playbook playbook.yml --tags install

# Skip NVIDIA setup
ansible-playbook playbook.yml --skip-tags nvidia
```

---

## Dependencies

None. This role is self-contained.

---

## Compatibility

| Distribution | Version | Status |
|--------------|---------|--------|
| Fedora | 38+ | ✅ Fully Supported |
| Ubuntu | 22.04+ | ✅ Fully Supported |
| Debian | 11+ | ✅ Supported |
| RHEL/CentOS | 8+ | ✅ Supported |
| Other Linux | N/A | ⚠️ Best Effort |

---

## Docker Conflict Handling

If Docker (moby-engine, docker-ce, docker.io) is already installed:

**Behavior:**
- Role detects conflict and warns
- Skips podman-docker/wrapper installation
- Provides migration instructions

**Recommended Action:**
1. Export existing Docker containers
2. Stop Docker daemon: `systemctl stop docker && systemctl disable docker`
3. Remove Docker: `dnf remove moby-engine` or `apt remove docker.io`
4. Re-run this role

---

## Examples

### Server Deployment

```yaml
- name: Deploy Podman on Linux servers
  hosts: linux_servers
  become: true
  roles:
    - role: podman_standard_linux
      tags: [podman_standard]
```

### GPU-Enabled Server

```yaml
- name: Deploy Podman with GPU support
  hosts: fedora_headless_gpu_nodes
  become: true
  roles:
    - role: podman_standard_linux
      vars:
        podman_nvidia_enabled: true
```

### Custom Storage Configuration

```yaml
- name: Deploy Podman with dedicated storage drive
  hosts: motoko
  become: true
  roles:
    - role: podman_standard_linux
      vars:
        podman_graphroot: /space/containers/engine/podman
        podman_configure_storage: true
        podman_create_storage_dirs: true
```

---

## Verification

After running this role:

```bash
# Verify Podman installation
podman --version
podman info

# Check storage path
podman info | grep graphRoot

# Verify Docker CLI compatibility
docker --version  # Should show Podman version
docker ps

# Test container run
podman run --rm docker.io/library/alpine:latest echo "Success!"
```

---

## Troubleshooting

### "docker: command not found"

**Cause:** Docker CLI compatibility not installed

**Fix:**
```bash
# Fedora
sudo dnf install podman-docker

# Ubuntu/Debian
sudo ln -s /usr/bin/podman /usr/local/bin/docker
```

### Docker Daemon Conflict

**Symptom:** Warning about Docker already installed

**Fix:** Follow migration steps in "Docker Conflict Handling" section

### NVIDIA GPU Not Detected

**Cause:** NVIDIA drivers not installed

**Fix:** Install NVIDIA drivers first:
```bash
# Fedora
sudo dnf install akmod-nvidia nvidia-container-toolkit

# Ubuntu
sudo apt install nvidia-driver-535 nvidia-container-toolkit
```

---

## Related Documentation

- [Container Runtime Standard](../../../docs/CONTAINERS_RUNTIME_STANDARD.md)
- [Podman Official Docs](https://docs.podman.io/)
- [Docker to Podman Migration](https://podman.io/getting-started/migration)

---

## License

Copyright (c) 2025 MikeT LLC. All rights reserved.

---

## Changelog

### Version 2.0 (2025-11-30)
- Renamed from `podman_base` to `podman_standard_linux`
- Added Ubuntu/Debian support
- Added Docker CLI wrapper for non-RedHat distros
- Enhanced Docker conflict detection
- Added comprehensive tagging
- Aligned with official container runtime standard

### Version 1.0 (2025-01-XX)
- Initial release as `podman_base`
- Fedora-only support

