# Legacy Scripts - DO NOT USE

**Status:** DEPRECATED  
**Date:** 2025-12-03

## Docker Scripts - BANNED

The following Docker-related scripts are deprecated and should NOT be used:

- `Debug-DockerNvidia.ps1` - Docker is banned

## Why These Are Here

These scripts are retained for historical reference only. Docker was removed from all
PHC systems on 2025-12-03. The approved container runtime is **Podman**.

## What To Use Instead

| Old (Docker) | New (Podman) |
|--------------|--------------|
| Docker Desktop | Podman Desktop |
| `docker ps` | `podman ps` |
| `docker run` | `podman run` |
| WSL2 Docker integration | WSL2 Podman |

## Automation

To enforce Docker prevention, use the Ansible role:

```bash
ansible-playbook playbooks/docker-prevention.yml --limit armitage
```

## See Also

- [Container Runtime Standard](../../../../docs/reference/CONTAINERS_RUNTIME_STANDARD.md)
- [Docker Prevention Role](../../../../ansible/roles/docker_prevention/README.md)
