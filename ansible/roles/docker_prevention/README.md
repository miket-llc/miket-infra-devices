# Docker Prevention Role

## Overview

This role actively prevents Docker installation and removes existing Docker artifacts from all PHC systems. **Docker is BANNED** from the entire system of systems - no exceptions.

## Policy

Docker is prohibited because:

1. **Runtime confusion**: Having both Docker and Podman causes operational confusion
2. **Security surface**: Docker daemon runs as root by default
3. **Licensing**: Docker Desktop has commercial licensing requirements
4. **Standardization**: Podman is the approved container runtime for PHC

## What This Role Does

### Linux
- Stops and disables Docker services
- Removes all Docker packages (docker-ce, moby-engine, containerd, etc.)
- Removes `podman-docker` (no Docker CLI emulation allowed)
- Removes Docker data directories (`/var/lib/docker`, etc.)
- Removes `docker0` network interface
- Blocks Docker package installation via dnf excludes/apt holds

### Windows
- Stops Docker Desktop services
- Uninstalls Docker Desktop silently
- Removes Docker Desktop files and configuration
- Checks for Docker in WSL2 instances
- Removes Docker from system PATH
- Creates marker file indicating Docker is banned

### macOS
- Stops Docker Desktop application
- Removes Docker Desktop app and all related files
- Uninstalls Docker if installed via Homebrew
- Removes Docker CLI symlinks
- Creates marker file indicating Docker is banned

## Usage

### Apply to all hosts
```bash
ansible-playbook playbooks/docker-prevention.yml
```

### Apply to specific host
```bash
ansible-playbook playbooks/docker-prevention.yml --limit motoko
```

### Apply via tags
```bash
ansible-playbook playbooks/linux-baseline.yml --tags docker_prevention
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `docker_prevention_enabled` | `true` | Enable Docker prevention |
| `docker_prevention_remove_packages` | `true` | Remove Docker packages |
| `docker_prevention_remove_data` | `true` | Remove Docker data directories |
| `docker_prevention_remove_networks` | `true` | Remove docker0 interface |
| `docker_prevention_block_install` | `true` | Block future Docker installation |
| `docker_prevention_remove_desktop_windows` | `true` | Remove Docker Desktop on Windows |
| `docker_prevention_remove_desktop_macos` | `true` | Remove Docker Desktop on macOS |
| `docker_prevention_block_wsl2` | `true` | Check/warn about Docker in WSL2 |

## Approved Alternatives

| Platform | Container Runtime | GUI Tool |
|----------|------------------|----------|
| Linux    | Podman           | Cockpit (optional) |
| Windows  | Podman Desktop   | Podman Desktop |
| macOS    | Podman Desktop   | Podman Desktop |

## Commands Reference

Instead of Docker commands, use:

| ❌ Docker (BANNED) | ✅ Podman (Use This) |
|-------------------|---------------------|
| `docker ps` | `podman ps` |
| `docker run` | `podman run` |
| `docker build` | `podman build` |
| `docker-compose up` | `podman-compose up` |
| `docker images` | `podman images` |
| `docker logs` | `podman logs` |

## Related Documentation

- [Container Runtime Standard](../../../docs/reference/CONTAINERS_RUNTIME_STANDARD.md)
- [Podman Standard Linux Role](../podman_standard_linux/README.md)
- [Podman Desktop Windows Role](../podman_desktop_windows/README.md)
- [Podman Desktop macOS Role](../podman_desktop_macos/README.md)




