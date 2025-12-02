# Legacy Scripts

These scripts have been archived as part of the Docker → Podman migration.

**Migration Date:** 2025-12-01

## Archived Scripts

- `Diagnose-DockerWSL.ps1` - Docker Desktop + WSL2 diagnostic tool (replaced by Podman Desktop)
- `Reset-DockerWSL.ps1` - Docker Desktop + WSL2 reset tool (replaced by Podman Desktop)

## Why Archived

The miket-infra-devices repository has standardized on **Podman** as the container runtime across all platforms:

- **Linux:** Podman with podman-docker CLI compatibility layer
- **Windows:** Podman Desktop with WSL2 backend
- **macOS:** Podman Desktop with Apple Hypervisor

Docker Desktop is no longer used. These scripts remain for historical reference only.

## Migration Notes

For the new Podman-based workflows, see:
- `../Start-VLLM.ps1` - Updated to use Podman
- `/docs/reference/CONTAINERS_RUNTIME_STANDARD.md` - Container runtime standard


