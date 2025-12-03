# Container Runtime Standard for miket-infra-devices

**Version:** 2.0  
**Date:** 2025-12-03  
**Status:** Active  

---

## Executive Summary

This document defines the **official container runtime standard** for all infrastructure devices in the miket-infra-devices ecosystem.

**TL;DR:**
- **ALL PLATFORMS:** Podman is the ONLY approved container runtime
- **Docker is BANNED:** No Docker, no Docker Desktop, no docker CLI, no exceptions
- **Commands:** Use native `podman` and `podman-compose` commands
- **Enforcement:** `docker_prevention` role actively blocks Docker installation

---

## ⛔ DOCKER BAN POLICY

**Effective: 2025-12-03**

Docker and all Docker-related software are **permanently banned** from all PHC systems:

| Banned Software | Reason |
|-----------------|--------|
| Docker Engine | Daemon-based, runs as root, security risk |
| Docker Desktop | Commercial licensing, resource hog |
| docker CLI | Introduces confusion with Podman |
| podman-docker | No CLI emulation - learn Podman commands |
| docker-compose | Use podman-compose instead |

**Enforcement:**
- The `docker_prevention` role is applied to all hosts
- Docker packages are blocked via dnf excludes / apt holds
- Any attempt to install Docker will fail
- Existing Docker installations are purged on playbook run

---

## 1. Design Principles

### 1.1 Core Tenets

1. **One Runtime:** Podman everywhere - Linux, Windows, macOS
2. **No Emulation:** Learn native Podman commands, no docker aliases
3. **Rootless Default:** Podman enables rootless containers by default
4. **Systemd Integration:** Containers are managed as systemd units on Linux servers
5. **No Exceptions:** Docker ban applies to all PHC systems including WSL2

### 1.2 Non-Goals

- ~~Docker CLI compatibility~~ **REMOVED** - use native Podman commands
- ~~Docker Desktop on Windows/macOS~~ **BANNED** - use Podman Desktop
- ~~Muscle memory support~~ **DEPRECATED** - retrain your muscle memory

---

## 2. Linux Runtime Standard

### 2.1 Primary Runtime: Podman

**What:**
- Podman is the ONLY container runtime for all Linux hosts
- All container operations use native Podman commands
- Containers are built, run, and managed via Podman

**Why:**
- Rootless by default (better security)
- Native systemd integration
- Daemonless architecture
- No commercial licensing concerns
- Better suited for servers and headless environments

### 2.2 Docker CLI Compatibility - REMOVED

**⛔ DEPRECATED AND REMOVED**

The `podman-docker` package and docker CLI wrappers are **no longer installed**.

Learn the native Podman commands:

| ❌ Docker (BANNED) | ✅ Podman (Use This) |
|-------------------|---------------------|
| `docker ps` | `podman ps` |
| `docker run nginx` | `podman run nginx` |
| `docker build -t app .` | `podman build -t app .` |
| `docker-compose up` | `podman-compose up` |
| `docker logs myapp` | `podman logs myapp` |
| `docker exec -it myapp bash` | `podman exec -it myapp bash` |

### 2.3 Compose Strategy

**Primary:** `podman-compose`
- Installed by default on all Linux hosts
- Compatible with most compose YAML files
- Natively integrates with Podman

**File Naming:**
- Compose files remain named `docker-compose.yml` (industry standard)
- Run with: `podman-compose up -d`

**Podman-Native Alternative:**
- For production services, use Podman systemd units (via `podman generate systemd`)
- Example: motoko services (Nextcloud, LiteLLM, vLLM) use systemd units

### 2.4 Storage Configuration

**Default Storage Paths:**
- **Root containers:** `/var/lib/containers/storage`
- **Rootless containers:** `~/.local/share/containers/storage`

**Custom Storage (motoko-specific):**
- motoko uses `/space/containers/engine/podman` (second internal drive)
- Configured via `/etc/containers/storage.conf.d/00-custom-storage.conf`

**Runtime Data:**
- `/run/containers/storage` (ephemeral)

---

## 3. Server vs Workstation Patterns

### 3.1 Linux Servers (Headless)

**Example:** motoko (Fedora Server)

**Pattern:**
- Podman installed as the only runtime
- Docker CLI compatibility via `podman-docker`
- All production services managed as systemd units
- No GUI tools (no Podman Desktop, no Docker Desktop)
- Containers run rootless where possible, rootful for system services

**Service Management:**
```bash
# Services managed via systemd
systemctl status nextcloud-app
systemctl status litellm
systemctl status vllm-embeddings

# Container inspection via Podman
podman ps
podman logs nextcloud-app
```

**Typical Roles:**
- `podman_standard_linux` (base runtime)
- `container_storage_device` (if using dedicated storage)
- `nextcloud_server` (Podman-based)
- `litellm_proxy` (Podman-based)
- `vllm-motoko` (Podman-based)

### 3.2 Linux Workstations (GUI)

**Pattern:**
- Podman installed for dev/test containers
- Docker CLI compatibility enabled
- Optional: Podman Desktop for visual container management
- Containers are ephemeral (dev tools, local testing)
- No long-running production workloads

**Typical Use Cases:**
- Running dev databases (PostgreSQL, Redis)
- Building container images locally
- Testing containerized applications
- Running ad-hoc containers for experimentation

**Typical Roles:**
- `common_dev_tools`
- `podman_standard_linux`
- `workstation_gui_tools` (Cursor, Warp, VS Code)

---

## 4. Windows/macOS Runtime Standard

### 4.1 Standard: Podman Desktop

**What:**
- Windows and macOS use **Podman Desktop** (GUI) + Podman CLI
- Docker Desktop is **BANNED** and actively removed
- Uses WSL2 on Windows, native Hypervisor on macOS

**Why:**
- **Consistency:** Same runtime across all platforms (Linux/Windows/macOS)
- **No licensing:** Podman Desktop is free for all use cases
- **No daemon:** Same architecture as Linux (daemonless)
- **No confusion:** One set of commands to learn

**How it works:**
- **Windows:** Podman uses WSL2 backend, GUI manages Linux VM
- **macOS:** Podman uses Apple Hypervisor framework, GUI manages Linux VM  
- **CLI:** Native `podman` commands only (no docker aliases)

### 4.2 Docker Prevention

The `docker_prevention` role is automatically applied to all Windows/macOS hosts:

- Uninstalls Docker Desktop if present
- Removes all Docker files and configuration
- Blocks Docker from being reinstalled
- Creates marker file indicating Docker is banned

**Commands on Windows/macOS:**
```powershell
# Windows (PowerShell)
podman ps
podman run -it alpine sh
podman-compose up -d
```

```bash
# macOS (Terminal)
podman ps
podman run -it alpine sh
podman-compose up -d
```

### 4.3 Unified Approach

**Consistency:**
- All platforms use Podman as the ONLY container runtime
- Linux: `podman_standard_linux` role (includes docker_prevention)
- macOS: `podman_desktop_macos` role + `docker_prevention` role
- Windows: `podman_desktop_windows` role + `docker_prevention` role

**Role deployment:**
```yaml
# Unified container runtime deployment with Docker prevention
- name: Prevent Docker (all platforms)
  ansible.builtin.include_role:
    name: docker_prevention

- name: Install Podman (Linux)
  ansible.builtin.include_role:
    name: podman_standard_linux
  when: ansible_system == "Linux"

- name: Install Podman Desktop (macOS)
  ansible.builtin.include_role:
    name: podman_desktop_macos
  when: ansible_os_family == "Darwin"

- name: Install Podman Desktop (Windows)
  ansible.builtin.include_role:
    name: podman_desktop_windows
  when: ansible_os_family == "Windows"
```

---

## 5. Implementation Details

### 5.1 Ansible Role: `podman_standard_linux`

**Responsibilities:**
1. Install Podman and related tools (`podman`, `podman-compose`, `buildah`, `skopeo`)
2. Install Docker CLI compatibility (`podman-docker` or wrapper script)
3. Configure container registries (docker.io, quay.io, ghcr.io)
4. Configure storage paths (default or custom)
5. Enable Podman socket for API access (optional)
6. Set up NVIDIA Container Toolkit (if GPU present)
7. Configure rootless containers (enable linger, systemd user dirs)

**Supports:**
- Fedora (primary)
- Ubuntu/Debian (secondary)
- Other distros (graceful degradation)

**Tags:**
- `podman_standard`
- `containers`
- `install`, `config`, `storage`, `verify`

### 5.2 motoko-Specific Pattern

**Baseline:**
- Uses `podman_standard_linux` like all other Linux hosts

**Extensions:**
- `container_storage_device` role points Podman storage to `/space` (second drive)
- All services deployed as Podman containers with systemd units
- Service directory structure: `/space/containers/apps/<service>/`

**Services:**
- Nextcloud (app + DB + Redis)
- LiteLLM Proxy
- vLLM Embeddings
- vLLM Reasoning (future)

**Configuration:**
```yaml
# host_vars/motoko/containers.yml
podman_graphroot: /space/containers/engine/podman
podman_runroot: /run/containers/storage
podman_nvidia_enabled: true
```

### 5.3 Playbook Integration

**Server Playbook:**
```yaml
# playbooks/linux-baseline.yml or playbooks/motoko/fedora-base.yml
- name: Configure Linux servers
  hosts: linux_servers
  roles:
    - role: podman_standard_linux
      tags: [podman_standard, containers]
```

**Workstation Playbook:**
```yaml
# playbooks/workstations/linux.yml
- name: Configure Linux workstations
  hosts: linux_workstations
  roles:
    - role: common_dev_tools
    - role: podman_standard_linux
      tags: [podman_standard, containers]
    - role: workstation_gui_tools
```

---

## 6. Migration Strategy

### 6.1 From Docker to Podman (Linux)

If a Linux host currently has Docker installed:

**Approach:**
1. **Audit existing Docker containers:** `docker ps -a`
2. **Export container definitions:** Convert to `docker-compose.yml` or systemd units
3. **Stop and disable Docker daemon:** `systemctl stop docker && systemctl disable docker`
4. **Uninstall Docker:** `dnf remove moby-engine docker-ce` or `apt remove docker.io`
5. **Install Podman via `podman_standard_linux` role**
6. **Re-deploy containers via Podman**
7. **Verify Docker CLI compatibility:** `docker ps` should work

**Rollback Plan:**
- Keep Docker container export tarballs
- Document original compose files
- Test Podman versions before removing Docker

### 6.2 Coexistence (Temporary)

In rare cases where Docker must coexist temporarily:

**Constraints:**
- Only one runtime should bind to the Docker socket at a time
- `podman-docker` cannot be installed if `moby-engine` is present
- Users must explicitly call `podman` or `docker` (no CLI ambiguity)

**Use Cases:**
- Testing Podman migration before full cutover
- Legacy application that absolutely requires Docker daemon
- Development/debugging scenarios

**Exit Criteria:**
- Migration complete and verified
- No remaining Docker dependencies

---

## 7. Operational Patterns

### 7.1 SRE Playbook Tags

To apply the Podman standard to any Linux host:

```bash
# Install Podman standard on all Linux servers
ansible-playbook playbooks/linux-baseline.yml --tags podman_standard

# Install on specific host
ansible-playbook playbooks/linux-baseline.yml --limit motoko --tags podman_standard

# Verify installation
ansible-playbook playbooks/linux-baseline.yml --tags containers,verify
```

### 7.2 Container Service Deployment Pattern

**Systemd Unit Approach (Preferred for Servers):**

```yaml
# Role: <service_name>
# Dependencies: podman_standard_linux

tasks:
  - name: Create service directory
    file:
      path: /space/containers/apps/myservice
      state: directory
  
  - name: Render container systemd unit
    template:
      src: myservice.service.j2
      dest: /etc/systemd/system/myservice.service
    notify: restart myservice
  
  - name: Enable and start service
    systemd:
      name: myservice
      enabled: true
      state: started
      daemon_reload: true
```

**Compose Approach (Preferred for Workstations/Dev):**

```yaml
tasks:
  - name: Render docker-compose.yml
    template:
      src: docker-compose.yml.j2
      dest: /opt/myservice/docker-compose.yml
  
  - name: Start service via podman-compose
    command: podman-compose -f /opt/myservice/docker-compose.yml up -d
    args:
      chdir: /opt/myservice
```

### 7.3 Verification Steps

**Basic Health Check:**
```bash
# Verify Podman installation
podman --version
podman info

# Check storage paths
podman info | grep graphRoot

# Verify Docker CLI compatibility
docker --version  # Should show Podman
docker ps

# Test container run
podman run --rm docker.io/library/alpine:latest echo "Podman works!"
```

**Service Health Check:**
```bash
# Check systemd services
systemctl status nextcloud-app litellm vllm-embeddings

# Check container status
podman ps
podman inspect <container_name>

# Check logs
journalctl -u nextcloud-app -f
podman logs -f nextcloud-app
```

---

## 8. QA Criteria

### 8.1 motoko (Fedora Server)

- [ ] `podman info` shows `graphRoot: /space/containers/engine/podman`
- [ ] No Docker daemon running (`systemctl status docker` fails)
- [ ] All services running via Podman: `podman ps` shows Nextcloud, LiteLLM, vLLM
- [ ] Docker CLI compatibility: `docker ps` works and shows same containers
- [ ] Systemd units active: `systemctl status nextcloud-app litellm vllm-embeddings`
- [ ] NVIDIA GPU accessible: `podman run --rm --device nvidia.com/gpu=all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi`

### 8.2 Linux Workstation (if applicable)

- [ ] Podman installed: `podman --version`
- [ ] Docker CLI compatibility: `docker ps` works
- [ ] `podman-docker` installed (Fedora) or wrapper present (Ubuntu)
- [ ] No Docker daemon running (`systemctl status docker` fails or not installed)
- [ ] Can run test container: `docker run --rm nginx:alpine`
- [ ] Registries configured: `podman info | grep -A5 registries`

### 8.3 Non-Linux Hosts (Windows/macOS)

- [ ] Docker Desktop **REMOVED**
- [ ] Podman Desktop installed and functional
- [ ] `podman ps` works
- [ ] `docker` command fails (not found)
- [ ] NO_DOCKER_ALLOWED marker file present

---

## 9. Troubleshooting

### 9.1 Common Issues

**Issue:** "docker: command not found" on Linux host

**Cause:** `podman-docker` not installed or wrapper not created

**Fix:**
```bash
# Fedora
sudo dnf install podman-docker

# Ubuntu/Debian
sudo ln -s /usr/bin/podman /usr/local/bin/docker
```

---

**Issue:** Podman containers not visible via `docker ps`

**Cause:** Root vs rootless context mismatch

**Fix:**
```bash
# Check root containers
sudo podman ps

# Check rootless containers
podman ps

# Docker alias uses rootless by default
docker ps  # Same as: podman ps
```

---

**Issue:** Permission denied when accessing Docker socket

**Cause:** Docker socket doesn't exist with Podman

**Fix:**
```bash
# Enable Podman socket (emulates Docker socket)
systemctl enable --now podman.socket

# Or use Podman-native CLI
podman ps
```

---

**Issue:** Compose file not working with podman-compose

**Cause:** Unsupported compose syntax or version

**Fix:**
```bash
# Check compose version
podman-compose --version

# Use Podman's native compose support (Podman 3.0+)
podman compose -f docker-compose.yml up -d

# Or convert to systemd units
podman generate systemd --new --files --name mycontainer
```

---

### 9.2 Performance Tuning

**Storage Driver:**
- Default: `overlay` (best performance)
- Alternative: `vfs` (debugging only, slow)

**Resource Limits:**
```bash
# CPU limits
podman run --cpus=2.0 myimage

# Memory limits
podman run --memory=2g myimage

# GPU limits (motoko)
podman run --device nvidia.com/gpu=all --env NVIDIA_VISIBLE_DEVICES=0 myimage
```

**Registry Mirrors:**
```bash
# Add to /etc/containers/registries.conf
[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "mirror.gcr.io"
```

---

## 10. Reference Commands

### 10.1 Podman Equivalents to Docker

| Docker Command | Podman Equivalent | Notes |
|----------------|-------------------|-------|
| `docker ps` | `podman ps` | Identical |
| `docker run` | `podman run` | Identical |
| `docker build` | `podman build` | Identical |
| `docker-compose up` | `podman-compose up` | Requires podman-compose |
| `docker exec -it` | `podman exec -it` | Identical |
| `docker logs` | `podman logs` | Identical |
| `docker images` | `podman images` | Identical |
| `docker pull` | `podman pull` | Identical |
| `docker push` | `podman push` | Identical |
| `systemctl restart docker` | `systemctl restart podman` | Socket, not daemon |

### 10.2 Podman-Specific Features

```bash
# Generate systemd unit from running container
podman generate systemd --new --files --name mycontainer

# Run rootless container (default)
podman run --rm alpine echo "No root required"

# Export container to systemd
podman generate kube mycontainer > mycontainer.yml

# Import Kubernetes YAML
podman play kube mycontainer.yml

# Check Podman system health
podman system info
podman system df  # Disk usage

# Prune unused containers/images
podman system prune -a
```

---

## 11. Future Considerations

### 11.1 Podman Desktop on Windows/macOS

**Status: DEPLOYED**

Podman Desktop is now the standard on all Windows/macOS hosts:
- ✅ Deployed to wintermute (Windows)
- ✅ Deployed to armitage (Windows)
- ✅ Deployed to count-zero (macOS)

Docker Desktop has been permanently banned and removed.

### 11.2 Kubernetes Integration

**Podman supports:**
- `podman play kube` - Run Kubernetes YAML directly
- `podman generate kube` - Export containers as K8s manifests

**Use Cases:**
- Local K8s development
- Simplified migration to K8s in future
- Unified orchestration format

### 11.3 Multi-Architecture Builds

**Podman supports:**
- `buildx`-equivalent multi-arch builds
- `buildah` for advanced build scenarios

**Example:**
```bash
# Build for amd64 and arm64
podman buildx build --platform linux/amd64,linux/arm64 -t myimage:latest .
```

---

## 12. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0 | 2025-12-03 | miket-infra-devices team | DOCKER BAN: Removed all Docker CLI compatibility, banned Docker Desktop, created docker_prevention role |
| 1.0 | 2025-11-30 | miket-infra-devices team | Initial standard definition |

---

## 13. References

- [Podman Documentation](https://docs.podman.io/)
- [Docker to Podman Migration Guide](https://podman.io/getting-started/migration)
- [Podman Compose](https://github.com/containers/podman-compose)
- [NVIDIA Container Toolkit with Podman](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html)
- [Ansible Role: podman_standard_linux](../ansible/roles/podman_standard_linux/README.md)

---

**Status:** This is the official container runtime standard for miket-infra-devices as of 2025-12-03. **ALL hosts** (Linux, Windows, macOS) must comply with this standard. Docker is permanently banned with no exceptions.

