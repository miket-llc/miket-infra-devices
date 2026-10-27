# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Hybrid Cloud (PHC) endpoint automation using Ansible. Manages Linux/Windows/macOS workstations and servers across a Tailscale mesh network.

**Subordination:** Platform-level resources (Tailscale ACLs, DNS, Entra ID, Azure Key Vault provisioning) are owned by `miket-infra` (Terraform). This repo consumes those contracts via Ansible.

**Key ADRs:**
- ADR-004: KDE Plasma is the standard Linux desktop for all UI nodes
- ADR-005: Workstations use Ollama; servers use vLLM
- ADR-0010: `/space` and Nextcloud migrated from motoko → akira (Dec 2025)

**Canonical architecture docs (read first for orientation):**
1. `docs/architecture/PHC_VNEXT_ARCHITECTURE.md` - System-wide principles
2. `docs/architecture/Miket_Infra_Devices_Architecture.md` - Device roles, automation layers, IaC/CaC boundary
3. `docs/architecture/FILESYSTEM_ARCHITECTURE.md` - Flux/Space/Time/Matter storage spec
4. `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md` - Nextcloud pure façade model

## Common Commands

```bash
# Primary interface - see all targets
make help

# Standard Ansible deployment pattern
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/<playbook>.yml --limit <host>

# Dry-run before applying changes (ALWAYS do this first)
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/<playbook>.yml --limit <host> --check --diff

# Run single task by tag
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/<playbook>.yml --tags "install" --limit <host>

# Note: ansible.cfg sets inventory and roles_path, so from the ansible/ dir you can omit -i:
#   cd ansible && ansible-playbook playbooks/<playbook>.yml --limit <host>

# Windows automation requires env vars first
set -a && source /etc/ansible/windows-automation.env && set +a

# Key deployments
make deploy-nextcloud          # Nextcloud stack on akira
make deploy-nomachine-servers  # NoMachine to Linux/Windows
make deploy-litellm            # LiteLLM proxy to akira
make deploy-observability      # Prometheus/Grafana stack
make deploy-data-lifecycle     # Backup services (space-mirror, restic)
make deploy-basecamp           # Basecamp node to atom
make deploy-llm-client         # LLM client tools + OpenHands to workstations

# System updates (Fedora fleet)
make update-all                # Update all hosts (packages + Tailscale + services)
make update-all-check          # Dry-run first (ALWAYS do this)
make update-host HOST=akira    # Update single host
make verify-services           # Check all services are running
make setup-update-scheduling   # Enable weekly automated updates

# Validation (run after deployments)
make validate-nextcloud        # Nextcloud pure façade compliance
make validate-litellm          # LiteLLM deployment
make validate-observability    # Monitoring stack health
make validate-backups          # Backup system operational
make verify-tailscale          # E2E Tailscale mesh verification
make validate-llm-client       # LLM client deployment

# Sync secrets from Azure Key Vault
ansible-playbook ansible/playbooks/secrets-sync.yml --limit <host>

# Testing
make test-context              # LiteLLM context window tests
make test-burst                # vLLM load tests
python3 tests/nextcloud_smoke.py
python3 tests/nomachine_smoke.py

# Device bootstrap (initial setup only)
scripts/bootstrap-macos.sh     # macOS: autofs, CLI tools, Tailscale
```

## Architecture

### Device Inventory
| Device | Role | OS | Key Services |
|--------|------|----|--------------|
| **akira** | Control node + Storage SoR + AI/server node | Fedora 44 KDE | **Ansible control**, **cloudflared tunnel** (`nextcloud.miket.io`), `/space` (18TB), `/time` export, Nextcloud, vLLM, LiteLLM, Prometheus/Grafana |
| **armitage** | Workstation + Ollama | Fedora KDE | Ollama (RTX 4070), NoMachine |
| **flatline** | Workstation | Fedora KDE | Basic workstation (Lenovo Yoga, no dedicated GPU) |
| **wintermute** | Windows workstation | Windows 11 | vLLM (RTX 4070 Super), NoMachine |
| **atom** | Hacker/radio node | Fedora | SDR, Sway/i3 UI, occasionally on |
| **count-zero** | macOS client | macOS | Autofs mounts, OS cloud ingestion |

> motoko was fully decommissioned (2026); its storage, control-node, and server duties moved to akira (see ADR-0010).

### Storage Model (Flux/Space/Time/Matter)
- **`/space`** - ONLY Source of Record. All data flows INTO `/space`; never mirror FROM it.
- **`/flux`** - Active workspace (hot, ephemeral)
- **`/time`** - Backup/history tier (read-mostly)
- **`/matter`** - Derived/cached data (embeddings, indexes, build artifacts). Rebuildable from `/space`.
- UX paths: `~/{flux,space,time,matter}` on Linux/macOS; `X:/S:/T:/M:` on Windows
- Ingestion: OS clouds (iCloud/OneDrive) flow one-way INTO `/space/devices/<host>/<user>/`
- Backups: `/space` → B2 object storage (via restic/rclone); never reverse

### Secrets Management
Secrets flow from Azure Key Vault → local `.env` files via `secrets-sync`:
1. Add mapping to `ansible/secrets-map.yml`
2. Run `ansible-playbook ansible/playbooks/secrets-sync.yml --limit <host>`
3. Services read from synced env files

**Key env file locations:**
- `/flux/apps/litellm/.env` - LiteLLM on akira
- `/flux/runtime/secrets/nextcloud.env` - Nextcloud credentials
- `/flux/runtime/secrets/grafana.env` - Grafana admin password
- `/etc/miket/storage-credentials.env` - B2/restic backup credentials
- `/etc/ansible/windows-automation.env` - WinRM passwords (akira control node)
- `~/.mkt/mounts.env` - SMB mount passwords (macOS)

**Never hardcode secrets. 1Password is for humans only.**

### LLM Fabric (AI Nodes)
Per ADR-005, LLM runtimes split by node type:
- **Workstations (Ollama):** armitage - interactive, model switching, `ollama run`
- **Servers (vLLM):** akira - high-throughput inference, OpenAI-compatible API
- **Gateway (LiteLLM):** akira:4000 - unified proxy, routes to vLLM backend
- **Clients:** Use `ASK_BASE_URL=http://akira:4000` for all LLM requests

### Service Deployment Lifecycle
Services (LiteLLM, Nextcloud, vLLM) follow this lifecycle:
1. **Storage ready:** Mount `/space` before starting containers
2. **Secrets synced:** Run `secrets-sync.yml` to render `.env` files from AKV
3. **Container/service start:** Systemd units with `EnvironmentFile=` pointing to synced env files
4. **Health check:** Services write `_status.json` to `/space/devices/<hostname>/`

Systemd units must declare: `Requires=<mount>.mount` and `After=<mount>.mount`

## Key Files
- `Makefile` - Primary task runner (`make help` for targets)
- `ansible/inventory/hosts.yml` - Device inventory + capability groups
- `ansible/secrets-map.yml` - AKV → .env mappings per service
- `ansible/playbooks/secrets-sync.yml` - Sync secrets from AKV to hosts
- `devices/<hostname>/` - Device-specific configs and scripts (e.g., `devices/wintermute/config.yml`)
- `docs/runbooks/` - Operational runbooks (70+ procedures)
- `docs/communications/COMMUNICATION_LOG.md` - Dated architectural decisions
- `scripts/tailscale-ssh-wrapper.sh` - SSH wrapper for Ansible (handles Tailscale auth)

### Playbook Organization
Most playbooks live in `ansible/playbooks/`. Host-specific playbooks are in subdirectories:
- `ansible/playbooks/akira/` - LiteLLM, data lifecycle, space setup
- `ansible/playbooks/atom/` - Basecamp UI, hacker/radio node config
- `ansible/playbooks/motoko/` - Nextcloud deployment (legacy, see ADR-0010)

Master orchestration playbooks (call sub-playbooks via `import_playbook`):
- `deploy-devices-infrastructure.yml` - Mounts + OS cloud sync across all clients
- `deploy-nomachine.yml` - NoMachine servers + clients fleet-wide
- `deploy-observability.yml` - node_exporter + Prometheus/Grafana stack

## Conventions

### Ansible Patterns
- Roles use `include_tasks` for modularity with OS-specific task files
- OS dispatch: `when: ansible_os_family == 'RedHat'` (or `'Darwin'`, `'Windows'`)
- All playbooks must be idempotent (use `creates`, `unless`, `changed_when: false`)
- Always test with `--check` and `--diff` first; use `--limit` for phased rollout
- GPU checks: Roles validate GPU presence before deploying GPU-dependent services (fail fast)
- Master playbooks use `import_playbook` to compose sub-playbooks with tags

### Inventory Groups
Key capability groups in `ansible/inventory/hosts.yml`:
- `linux`, `windows`, `macos` - OS families
- `gpu_8gb`, `gpu_12gb`, `gpu_unified_memory` - GPU capability tiers
- `cuda_nodes`, `rocm_nodes` - GPU compute frameworks
- `llm_workstations_ollama`, `llm_servers_vllm` - LLM runtime pattern (ADR-005)
- `fedora_kde_workstations` - KDE Plasma desktops (ADR-004)
- `headless_servers`, `basecamp_nodes` - Server/hacker node modes
- `monitoring_exporters`, `monitoring_stack` - Prometheus infrastructure
- `container_hosts` - Nodes running Podman
- `llm_client_nodes` - Nodes that consume the LiteLLM gateway

### Container Runtime Standard
**Podman-only** - no Docker daemon. CI guardrail (`.github/workflows/podman-only-guardrail.yml`) rejects Docker daemon/service references and `community.docker` Ansible modules on every PR.
- Use `containers.podman` Ansible collection (not `community.docker`)
- Use `podman-compose.yml` (not `docker-compose.yml`)
- Docker CLI compatibility via `podman-docker` package is allowed (muscle memory)
- Reference: `docs/reference/CONTAINERS_RUNTIME_STANDARD.md`

### Pre-commit Hooks
Copyright header check runs on all text files via `scripts/pre-commit-copyright-check.sh`. Install with:
```bash
pip install pre-commit && pre-commit install
```

## Critical Invariants and Pitfalls

1. **`/space` is the only SoR** - Never mirror FROM `/space` to external clouds; `/space` is the destination, not a source
2. **Nextcloud is a pure façade** - External storage to `/space/mike/*` only; no internal homes. Don't expose `/space/projects`, `/space/code`, `/space/dev`
3. **Secrets from AKV** - Never hardcode; always use `secrets-sync`
4. **Tailscale hostnames** - Always use MagicDNS (`*.pangolin-vega.ts.net`), never IPs (ACL changes may reassign IPs)
5. **OS cloud loop prevention** - iCloud/OneDrive must NOT sync back from network mounts; use `rsync --no-links` on macOS autofs
6. **Windows WinRM env vars** - Must source `/etc/ansible/windows-automation.env` before running Windows playbooks
7. **Podman-only** - Never introduce Docker daemon references; CI will reject them

## File Organization

- **Architecture docs:** `docs/architecture/` (canonical, slow-changing)
- **Operational docs:** `docs/runbooks/`, `docs/troubleshooting/` (procedures, fast-changing)
- **Scripts:** `scripts/` (bootstrap, diagnosis, one-off fixes; NOT for long-term automation)
- **Ansible:** `ansible/playbooks/`, `ansible/roles/` (reusable automation)
- **Device configs:** `devices/<hostname>/` (device-specific overrides)

## When Making Changes

1. **Architecture changes:** Update canonical docs in `docs/architecture/`, log decision in `COMMUNICATION_LOG.md`
2. **New secrets:** Add mapping to `secrets-map.yml`, provision in AKV (upstream), run `secrets-sync.yml`
3. **New services:** Document storage paths, prove `/space` alignment, add systemd mount deps
4. **New devices:** Add to `ansible/inventory/hosts.yml`, create `devices/<hostname>/config.yml`, apply Tailscale tags (upstream ACL)
5. **Always validate:** Run the corresponding `make validate-*` target after deployment
6. **Test first:** Always `--check --diff` before applying; use `--limit` for phased rollout

## Creating New Roles

New Ansible roles follow this structure:
```
ansible/roles/<role_name>/
├── tasks/
│   ├── main.yml           # OS dispatch using include_tasks
│   ├── fedora.yml         # or linux.yml for generic Linux
│   ├── macos.yml
│   └── windows.yml
├── templates/             # Jinja2 templates (*.j2)
├── files/                 # Static files
├── handlers/main.yml      # Service restart handlers
└── defaults/main.yml      # Default variables
```

OS dispatch pattern in `main.yml`:
```yaml
- name: Include OS-specific tasks
  ansible.builtin.include_tasks: "{{ ansible_os_family | lower }}.yml"
  when: ansible_os_family in ['RedHat', 'Darwin', 'Windows']
```

## Debugging Ansible

```bash
# Verbose output (add more v's for more detail)
ansible-playbook ... -vvv

# Run single task by tag
ansible-playbook ... --tags "install"

# Skip certain tags
ansible-playbook ... --skip-tags "restart"

# Check connectivity to hosts
ansible -i ansible/inventory/hosts.yml all -m ping

# Run ad-hoc command
ansible -i ansible/inventory/hosts.yml akira -m shell -a "systemctl status litellm"
```

## Tailscale SSH

This repo uses Tailscale SSH for most Linux hosts. The wrapper script handles auth:

```bash
# Direct Tailscale SSH
tailscale ssh mdt@akira.pangolin-vega.ts.net

# Via wrapper (for Ansible)
/home/mdt/dev/miket-infra-devices/scripts/tailscale-ssh-wrapper.sh mdt@akira

# Verify mesh connectivity
./scripts/verify-tailscale-e2e.sh
```

Hostnames always use MagicDNS format: `<device>.pangolin-vega.ts.net`
