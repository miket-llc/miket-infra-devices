# Legacy Scripts

These scripts have been archived as part of the Docker → Podman migration.

**Migration Date:** 2025-12-01

## Archived Scripts

- `deploy-armitage-docker-monitor.sh` - Docker deployment monitoring script (obsolete)

## Why Archived

The miket-infra-devices repository has standardized on **Podman** as the container runtime across all platforms:

- **Linux:** Podman with podman-docker CLI compatibility layer
- **Windows:** Podman Desktop with WSL2 backend
- **macOS:** Podman Desktop with Apple Hypervisor

Docker Desktop is no longer used. These scripts remain for historical reference only.

## Migration Notes

For the new Podman-based workflows, see:
- `/docs/reference/CONTAINERS_RUNTIME_STANDARD.md` - Container runtime standard
- `/ansible/roles/podman_standard_linux/` - Podman deployment role


