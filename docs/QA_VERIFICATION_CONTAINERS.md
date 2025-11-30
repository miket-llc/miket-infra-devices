# Container Runtime Standard - QA Verification Guide

**Version:** 1.0  
**Date:** 2025-11-30  
**Purpose:** Verification procedures for the Podman container runtime standard

---

## Overview

This document provides step-by-step QA verification procedures to validate that the container runtime standard has been correctly applied across the infrastructure.

---

## 1. Linux Servers (Headless) - motoko Example

### Prerequisites
- SSH access to host
- sudo privileges

### Verification Steps

#### 1.1 Podman Installation

```bash
# Verify Podman is installed
podman --version
# Expected: podman version 4.x.x or later

# Check Podman info
podman info

# Verify graphRoot location
podman info | grep graphRoot
# Expected (motoko): /space/containers/engine/podman
# Expected (other Linux): /var/lib/containers/storage
```

#### 1.2 Docker CLI Compatibility

```bash
# Verify docker command exists
which docker
# Expected: /usr/bin/docker (Fedora) or /usr/local/bin/docker (Ubuntu)

# Check docker version (should show Podman)
docker --version
# Expected: Shows Podman version, not Docker

# Test docker ps
docker ps
# Expected: Works, shows Podman containers

# Verify docker and podman show same containers
diff <(docker ps -q | sort) <(podman ps -q | sort)
# Expected: No differences
```

#### 1.3 Docker Daemon Check

```bash
# Ensure no Docker daemon is running
systemctl status docker
# Expected: Unit docker.service could not be found OR inactive/dead

# Check for conflicting packages
rpm -qa | grep -E 'docker|moby' | grep -v podman-docker
# Expected (Fedora): No output or only podman-docker

dpkg -l | grep -E 'docker|moby'
# Expected (Ubuntu): No Docker packages OR ii  status for podman only
```

#### 1.4 Container Test

```bash
# Test basic container run
podman run --rm docker.io/library/alpine:latest echo "Podman works"
# Expected: "Podman works"

# Test with docker CLI
docker run --rm alpine:latest echo "Docker CLI works"
# Expected: "Docker CLI works"
```

#### 1.5 Service Verification (motoko)

```bash
# Check Podman containers running
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
# Expected: See LiteLLM, vLLM, Nextcloud containers (if deployed)

# Check systemd services
systemctl status litellm vllm-embeddings vllm-reasoning nextcloud-app
# Expected: active (running)

# Check logs
journalctl -u litellm -n 50 --no-pager
podman logs litellm
# Expected: Service logs, no critical errors
```

#### 1.6 NVIDIA GPU Support (if applicable)

```bash
# Test GPU container access
podman run --rm --device nvidia.com/gpu=all \
  docker.io/nvidia/cuda:12.3.1-base-ubuntu22.04 nvidia-smi
# Expected: Shows GPU info

# Verify CDI configuration
ls -la /etc/cdi/nvidia.yaml
# Expected: File exists with nvidia CDI spec
```

#### 1.7 Storage Configuration (motoko-specific)

```bash
# Verify /space mount
df -h /space
# Expected: Shows mounted second drive

# Check Podman storage
podman system df
# Expected: Shows storage usage on correct path

# Verify graphRoot
podman info --format '{{.Store.GraphRoot}}'
# Expected: /space/containers/engine/podman
```

---

## 2. Linux Workstations

### Prerequisites
- Access to workstation
- GUI or SSH access

### Verification Steps

#### 2.1 Podman Installation

```bash
podman --version
# Expected: podman version 4.x.x or later

podman info | grep graphRoot
# Expected: /var/lib/containers/storage (default)
```

#### 2.2 Docker CLI Compatibility

```bash
which docker
# Expected: /usr/bin/docker or /usr/local/bin/docker

docker --version
# Expected: Shows Podman version

docker ps
# Expected: Works
```

#### 2.3 No Conflicting Docker

```bash
systemctl status docker
# Expected: Not found or inactive

# Fedora
rpm -qa | grep -E 'docker' | grep -v podman
# Expected: No output

# Ubuntu
dpkg -l | grep docker
# Expected: No docker.io or docker-ce packages
```

#### 2.4 Container Test

```bash
# Test container operations
docker run --rm nginx:alpine echo "Test"
podman-compose --version
# Expected: Both work
```

#### 2.5 Optional: Podman Desktop (if installed)

```bash
# Check if Podman Desktop is running
ps aux | grep podman-desktop
flatpak list | grep podman
# Expected: Shows Podman Desktop if installed
```

---

## 3. Windows/macOS Workstations

### Prerequisites
- Access to Windows/macOS workstation

### Verification Steps

#### 3.1 Docker Desktop (Should be unchanged)

**Windows:**
```powershell
docker --version
# Expected: Docker version (not Podman)

docker ps
# Expected: Works with Docker Desktop

Get-Service -Name "com.docker.*"
# Expected: Docker services running
```

**macOS:**
```bash
docker --version
# Expected: Docker version (not Podman)

docker ps
# Expected: Works with Docker Desktop

ps aux | grep Docker
# Expected: Docker.app processes
```

#### 3.2 No Podman Changes

```bash
# Verify no Podman was installed
which podman
# Expected: Command not found (on Windows/macOS)
```

---

## 4. Cross-Host Verification

### 4.1 Inventory Consistency

```bash
# On Ansible control node
cd /home/mdt/dev/miket-infra-devices/ansible

# Check which hosts have Podman role applied
ansible-inventory --list | jq '.linux.hosts'
# Expected: Shows Linux hosts

# Verify Podman on all Linux hosts
ansible linux -m command -a "podman --version"
# Expected: All Linux hosts report Podman version

# Verify Docker CLI compat
ansible linux -m command -a "docker --version"
# Expected: All report Podman version (not Docker)
```

### 4.2 Service Availability

```bash
# Check container services across fleet
ansible container_hosts -m command -a "podman ps --format '{{.Names}}'"
# Expected: Shows running containers per host
```

---

## 5. QA Checklist

### Linux Servers (e.g., motoko)

- [ ] Podman installed and version >= 4.0
- [ ] `podman info` shows correct graphRoot
- [ ] `docker` command exists and maps to Podman
- [ ] `docker ps` works and shows Podman containers
- [ ] No Docker daemon running
- [ ] No conflicting Docker packages
- [ ] Container test passes (alpine echo test)
- [ ] Services running via systemd
- [ ] NVIDIA GPU accessible from containers (if GPU present)
- [ ] Storage on correct path (motoko: /space)

### Linux Workstations

- [ ] Podman installed
- [ ] Docker CLI compatibility working
- [ ] No Docker daemon conflicts
- [ ] Container test passes
- [ ] `podman-compose` available

### Windows/macOS Workstations

- [ ] Docker Desktop functioning normally
- [ ] No Podman installed or configured
- [ ] Container workflows unchanged

---

## 6. Common Issues & Resolutions

### Issue: "docker: command not found" on Linux

**Resolution:**
```bash
# Fedora
sudo dnf install podman-docker

# Ubuntu/Debian
sudo ln -s /usr/bin/podman /usr/local/bin/docker
```

### Issue: Docker daemon still running

**Resolution:**
```bash
sudo systemctl stop docker
sudo systemctl disable docker

# Optionally remove Docker
sudo dnf remove moby-engine docker-ce  # Fedora
sudo apt remove docker.io docker-ce    # Ubuntu
```

### Issue: Podman containers not visible via `docker ps`

**Cause:** Root vs rootless context mismatch

**Resolution:**
```bash
# Check root containers
sudo podman ps

# Check rootless containers (as user)
podman ps

# Ensure docker alias uses same context
docker ps  # Should match: podman ps
```

### Issue: Permission denied accessing containers

**Resolution:**
```bash
# Check user groups
groups

# Add user to necessary groups (if needed)
sudo usermod -aG users $USER

# Enable lingering for rootless containers
sudo loginctl enable-linger $USER
```

### Issue: NVIDIA GPU not accessible in containers

**Resolution:**
```bash
# Verify NVIDIA drivers
nvidia-smi

# Check NVIDIA Container Toolkit
nvidia-ctk --version

# Regenerate CDI spec
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# Test GPU container
podman run --rm --device nvidia.com/gpu=all nvidia/cuda:12.3.1-base-ubuntu22.04 nvidia-smi
```

---

## 7. Automated Verification Playbook

```yaml
---
# verify-container-standard.yml
- name: Verify Container Runtime Standard
  hosts: linux
  gather_facts: true

  tasks:
    - name: Check Podman installation
      ansible.builtin.command: podman --version
      register: podman_check
      changed_when: false

    - name: Check Docker CLI compatibility
      ansible.builtin.command: docker --version
      register: docker_cli_check
      changed_when: false

    - name: Verify no Docker daemon
      ansible.builtin.systemd:
        name: docker
        state: stopped
      register: docker_daemon_check
      failed_when: false
      changed_when: false

    - name: Test container run
      ansible.builtin.command: podman run --rm alpine:latest echo "OK"
      register: container_test
      changed_when: false

    - name: Display verification results
      ansible.builtin.debug:
        msg: |
          Host: {{ inventory_hostname }}
          Podman: {{ podman_check.stdout }}
          Docker CLI: {{ 'Working' if docker_cli_check.rc == 0 else 'FAILED' }}
          Docker Daemon: {{ 'Stopped ✓' if docker_daemon_check.failed else 'RUNNING ✗' }}
          Container Test: {{ 'Passed ✓' if container_test.rc == 0 else 'FAILED ✗' }}
```

**Usage:**
```bash
ansible-playbook playbooks/verify-container-standard.yml
```

---

## 8. Acceptance Criteria Summary

| Criterion | motoko | Other Linux Servers | Linux Workstations | Windows/macOS |
|-----------|--------|---------------------|-------------------|---------------|
| Podman installed | ✅ | ✅ | ✅ | ❌ |
| Docker CLI works | ✅ | ✅ | ✅ | ✅ (Docker Desktop) |
| No Docker daemon | ✅ | ✅ | ✅ | ❌ (Docker Desktop OK) |
| Custom storage | ✅ (/space) | ⚠️ (if needed) | ❌ (default) | N/A |
| NVIDIA GPU support | ✅ | ⚠️ (if GPU) | ⚠️ (if GPU) | N/A |
| Services via systemd | ✅ | ✅ | ❌ | N/A |

---

## 9. References

- [Container Runtime Standard](CONTAINERS_RUNTIME_STANDARD.md)
- [Podman Documentation](https://docs.podman.io/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [podman_standard_linux Role](../ansible/roles/podman_standard_linux/README.md)

---

**Document Status:** Active  
**Last Updated:** 2025-11-30

