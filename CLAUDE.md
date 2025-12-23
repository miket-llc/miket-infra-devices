# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Hybrid Cloud (PHC) endpoint automation using Ansible. Manages Linux/Windows/macOS workstations and servers across a Tailscale mesh network.

**Subordination:** Platform-level resources (Tailscale ACLs, DNS, Entra ID, Azure Key Vault provisioning) are owned by `miket-infra` (Terraform). This repo consumes those contracts via Ansible.

**Key ADRs:**
- ADR-004: KDE Plasma is the standard Linux desktop for all UI nodes
- ADR-005: Workstations use Ollama; servers use vLLM
- ADR-0010: `/space` and Nextcloud migrated from motoko → akira (Dec 2025)

## Common Commands

```bash
# Primary interface - see all targets
make help

# Standard Ansible deployment pattern
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/<playbook>.yml --limit <host>

# Dry-run before applying changes (ALWAYS do this first)
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/<playbook>.yml --limit <host> --check --diff

# Windows automation requires env vars first
set -a && source /etc/ansible/windows-automation.env && set +a

# Key deployments
make deploy-nextcloud          # Nextcloud stack on akira
make deploy-nomachine-servers  # NoMachine to Linux/Windows
make deploy-litellm            # LiteLLM proxy to akira
make deploy-observability      # Prometheus/Grafana stack
make deploy-data-lifecycle     # Backup services (space-mirror, restic)
make deploy-basecamp           # Basecamp node to atom

# Validation (run after deployments)
make validate-nextcloud        # Nextcloud pure façade compliance
make validate-litellm          # LiteLLM deployment
make validate-observability    # Monitoring stack health
make validate-backups          # Backup system operational
make verify-tailscale          # E2E Tailscale mesh verification

# Sync secrets from Azure Key Vault
ansible-playbook ansible/playbooks/secrets-sync.yml --limit <host>

# Testing
make test-context              # LiteLLM context window tests
make test-burst                # vLLM load tests
python3 tests/nextcloud_smoke.py
python3 tests/nomachine_smoke.py

# Device bootstrap (initial setup only)
scripts/bootstrap-macos.sh     # macOS: autofs, CLI tools, Tailscale
scripts/bootstrap-motoko.sh    # motoko: Ansible control node setup
```

## Architecture

### Device Inventory
| Device | Role | OS | Key Services |
|--------|------|----|--------------|
| **motoko** | Server/control node | Fedora | Ansible control, cloudflared tunnel |
| **akira** | Storage SoR + AI workstation | Fedora 43 KDE | `/space` (18TB), Nextcloud, vLLM, LiteLLM, Prometheus/Grafana |
| **armitage** | Workstation + Ollama | Fedora KDE | Ollama (RTX 4070), NoMachine |
| **wintermute** | Windows workstation | Windows 11 | vLLM (RTX 4070 Super), NoMachine |
| **atom** | Basecamp/resilience node | Fedora | Battery-backed, Sway/i3 UI, SSH foothold |
| **count-zero** | macOS client | macOS | Autofs mounts, OS cloud ingestion |

### Storage Model (Flux/Space/Time)
- **`/space`** - ONLY Source of Record. All data flows INTO `/space`; never mirror FROM it.
- **`/flux`** - Active workspace (hot, ephemeral)
- **`/time`** - Backup/history tier (read-mostly)
- UX paths: `~/{flux,space,time}` on Linux/macOS; `X:/S:/T:` on Windows

### Secrets Management
Secrets flow from Azure Key Vault → local `.env` files via `secrets-sync`:
1. Add mapping to `ansible/secrets-map.yml`
2. Run `ansible-playbook ansible/playbooks/secrets-sync.yml --limit <host>`
3. Services read from synced env files (e.g., `/flux/apps/litellm/.env`)

**Never hardcode secrets. 1Password is for humans only.**

## Key Files
- `Makefile` - Primary task runner (`make help` for targets)
- `ansible/inventory/hosts.yml` - Device inventory + capability groups
- `ansible/secrets-map.yml` - AKV → .env mappings per service
- `ansible/playbooks/secrets-sync.yml` - Sync secrets from AKV to hosts
- `docs/architecture/PHC_VNEXT_ARCHITECTURE.md` - PHC big picture
- `docs/architecture/FILESYSTEM_ARCHITECTURE.md` - Flux/Space/Time storage model
- `docs/runbooks/` - Operational runbooks (70+ procedures)
- `docs/communications/COMMUNICATION_LOG.md` - Dated architectural decisions

## Conventions

### Ansible Patterns
- Roles use `include_tasks` for modularity with OS-specific task files
- OS dispatch: `when: ansible_os_family == 'RedHat'` (or `'Darwin'`, `'Windows'`)
- All playbooks must be idempotent (use `creates`, `unless`, `changed_when: false`)
- Always test with `--check` and `--diff` first; use `--limit` for phased rollout

### Inventory Groups
Key capability groups in `ansible/inventory/hosts.yml`:
- `linux`, `windows`, `macos` - OS families
- `gpu_8gb`, `gpu_12gb`, `gpu_unified_memory` - GPU capability tiers
- `cuda_nodes`, `rocm_nodes` - GPU compute frameworks
- `llm_workstations_ollama`, `llm_servers_vllm` - LLM runtime pattern (ADR-005)
- `fedora_kde_workstations` - KDE Plasma desktops (ADR-004)
- `headless_servers`, `basecamp_nodes` - Server/workstation modes
- `monitoring_exporters`, `monitoring_stack` - Prometheus infrastructure
- `container_hosts` - Nodes running Podman/Docker

### Service Dependencies
Systemd services must declare storage dependencies:
```ini
Requires=<mount>.mount
After=<mount>.mount
```

## Critical Invariants

1. **`/space` is the only SoR** - Never mirror FROM `/space` to external clouds
2. **Nextcloud is a pure façade** - External storage to `/space/mike/*` only; no internal homes
3. **Secrets from AKV** - Never hardcode; always use `secrets-sync`
4. **Tailscale hostnames** - Always use MagicDNS (`*.pangolin-vega.ts.net`), never IPs
5. **OS cloud loop prevention** - iCloud/OneDrive must NOT sync back from network mounts
6. **systemd mount dependencies** - Services must declare `Requires=` and `After=` for mounts

## Common Pitfalls

- **Don't mirror FROM `/space`** - `/space` is the destination, not a source for external clouds
- **Don't skip AKV for secrets** - Hardcoded passwords will break; use `secrets-sync`
- **Don't use IPs in mount scripts** - Always use MagicDNS hostnames (ACL changes may reassign IPs)
- **macOS autofs loop prevention** - Use `--no-links` with rsync to avoid following symlinks back into autofs mounts
- **Windows WinRM env vars** - Must source `/etc/ansible/windows-automation.env` before running Windows playbooks
- **Nextcloud prohibited paths** - Don't expose `/space/projects`, `/space/code`, `/space/dev` via external storage

## When Making Changes

1. **Architecture changes:** Update `docs/architecture/`, log in `COMMUNICATION_LOG.md`
2. **New secrets:** Add to `secrets-map.yml`, provision in AKV (upstream), run `secrets-sync.yml`
3. **New services:** Document storage paths, prove `/space` alignment, add systemd mount deps
4. **Always validate:** Run the corresponding `make validate-*` target after deployment

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
