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

# Windows automation requires env vars first
set -a && source /etc/ansible/windows-automation.env && set +a

# Key deployments
make deploy-nextcloud          # Nextcloud stack on akira
make deploy-nomachine-servers  # NoMachine to Linux/Windows
make deploy-proxy              # LiteLLM proxy to motoko
make deploy-baseline-tools     # Common dev tools (Warp, Cursor, etc.)

# Master orchestration playbooks (call sub-playbooks via import_playbook)
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-devices-infrastructure.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-nomachine.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-observability.yml

# Testing
make test-context              # LiteLLM context window tests
make test-burst                # vLLM load tests
python3 tests/nextcloud_smoke.py
python3 tests/nomachine_smoke.py

# Validation
ansible-playbook ansible/playbooks/validate-devices-infrastructure.yml
make verify-tailscale          # E2E Tailscale mesh verification

# Device bootstrap (initial setup only)
scripts/bootstrap-macos.sh     # macOS: autofs, CLI tools, Tailscale
scripts/bootstrap-motoko.sh    # motoko: Ansible control node setup
```

## Architecture

### Device Inventory
| Device | Role | OS | Key Services |
|--------|------|----|--------------|
| **motoko** | Server/control node | Fedora | Ansible control, LiteLLM proxy, cloudflared tunnel |
| **akira** | Storage SoR + AI workstation | Fedora 43 KDE | `/space` (18TB), Nextcloud, vLLM (AMD Strix Point), Prometheus/Grafana |
| **armitage** | Workstation + Ollama | Fedora KDE | Ollama (RTX 4070), NoMachine |
| **wintermute** | Windows workstation | Windows 11 | vLLM (RTX 4070 Super), NoMachine |
| **atom** | Resilience node | Fedora | Battery-backed SSH foothold, headless |
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
3. Services read from synced env files (e.g., `/podman/apps/litellm/.env`)

**Never hardcode secrets. 1Password is for humans only.**

## Key Files
- `Makefile` - Primary task runner (70+ targets)
- `ansible/inventory/hosts.yml` - Device inventory + groups
- `ansible/secrets-map.yml` - AKV → .env mappings
- `docs/architecture/` - Canonical architecture docs
- `docs/communications/COMMUNICATION_LOG.md` - Dated architectural decisions

## Conventions

### Ansible Patterns
- Roles use `include_tasks` for modularity
- OS-specific: `when: ansible_os_family == 'RedHat'`
- All playbooks must be idempotent (use `creates`, `unless`, `changed_when: false`)
- Always test with `--check` and `--diff` first; use `--limit` for phased rollout

### Inventory Groups
- `linux`, `windows`, `macos` - OS families
- `gpu_8gb`, `gpu_12gb`, `gpu_unified_memory` - GPU capability tiers
- `cuda_nodes`, `rocm_nodes` - GPU compute frameworks
- `llm_workstations_ollama`, `llm_servers_vllm` - LLM runtime pattern (ADR-005)
- `fedora_kde_workstations` - KDE Plasma desktops (ADR-004)
- `headless_servers` - SSH-only nodes (no GUI)
- `wol_enabled` - Wake-on-LAN capable
- `monitoring_exporters` - Hosts running node_exporter
- `monitoring_stack` - Host running Prometheus/Grafana (akira)
- `container_hosts` - Nodes running Podman/Docker

### Service Dependencies
Systemd services must declare storage dependencies:
```ini
Requires=<mount>.mount
After=<mount>.mount
```

### Monitoring (Prometheus/Grafana)
- **Architecture:** Prometheus + Grafana + Blackbox on akira; node_exporter on Linux servers
- **Tailnet-only access** - All monitoring ports restricted to 100.64.0.0/10
- **Grafana UI:** `http://akira.pangolin-vega.ts.net:3000` (dashboards, visualization)
- **Prometheus UI:** `http://akira.pangolin-vega.ts.net:9090` (queries, targets)
- **Deployment:** `make deploy-observability` or `ansible-playbook ansible/playbooks/deploy-observability.yml`
- **Runbook:** `docs/runbooks/monitoring-prometheus-grafana.md`

## Critical Invariants

1. **`/space` is the only SoR** - Never mirror FROM `/space` to external clouds
2. **Nextcloud is a pure façade** - External storage to `/space/mike/*` only; no internal homes
3. **Secrets from AKV** - Never hardcode; always use `secrets-sync`
4. **Tailscale hostnames** - Always use MagicDNS (`*.pangolin-vega.ts.net`), never IPs
5. **OS cloud loop prevention** - iCloud/OneDrive must NOT sync back from network mounts
6. **systemd mount dependencies** - Services must declare `Requires=<mount>.mount` and `After=<mount>.mount`

**ADRs in effect:**
- ADR-004: KDE Plasma is the standard Linux desktop for all UI nodes
- ADR-005: Workstations use Ollama; servers use vLLM
- ADR-0010: `/space` and Nextcloud migrated from motoko → akira (Dec 2025)

## Common Pitfalls

- **Don't mirror FROM `/space`** - `/space` is the destination, not a source for external clouds
- **Don't skip AKV for secrets** - Hardcoded passwords will break; use `secrets-sync`
- **Don't use IPs in mount scripts** - Always use MagicDNS hostnames (ACL changes may reassign IPs)
- **macOS autofs loop prevention** - Use `--no-links` with rsync to avoid following symlinks back into autofs mounts
- **Windows WinRM env vars** - Must source `/etc/ansible/windows-automation.env` before running Windows playbooks
- **systemd mount dependencies** - Always add `Requires=` and `After=` for storage-dependent services

## When Making Changes

1. **Architecture changes:** Update `docs/architecture/`, log in `COMMUNICATION_LOG.md`
2. **New secrets:** Add to `secrets-map.yml`, provision in AKV (upstream), run `secrets-sync.yml`
3. **New services:** Document storage paths, prove `/space` alignment, add systemd mount deps
4. **Always validate:** `ansible-playbook ansible/playbooks/validate-*.yml`

## Role Patterns

Roles follow a consistent structure with OS-specific task files:
```
ansible/roles/<role_name>/
├── tasks/
│   ├── main.yml           # Entry point with OS dispatch
│   ├── linux.yml          # or fedora.yml, ubuntu.yml
│   ├── macos.yml
│   └── windows.yml
├── templates/             # Jinja2 templates
├── files/                 # Static files
└── defaults/main.yml      # Default variables
```

Common role categories:
- `mount_shares_*` - Flux/Space/Time mounts per OS
- `remote_*` - NoMachine server/client deployment
- `llm_*` - LLM runtime (Ollama workstation, vLLM server)
- `secrets_sync` - AKV → .env synchronization
- `*_fedora`, `*_ubuntu`, `*_windows` - OS-specific variants

## Common Pitfalls

1. **Don't mirror FROM `/space`** - `/space` is the destination, not a source for external clouds
2. **Don't use IPs in mount scripts** - Always use MagicDNS hostnames (ACL changes may reassign IPs)
3. **Don't expose prohibited paths via Nextcloud** - External storage limited to `/space/mike/*` (no `/space/projects/**`, `/space/code/**`)
4. **macOS autofs loop prevention** - Use `--no-links` with rsync to avoid following symlinks back into autofs mounts
5. **Windows WinRM env vars** - Must source `/etc/ansible/windows-automation.env` before running Windows playbooks
6. **Nextcloud prohibited paths** - Don't expose `/space/projects`, `/space/code`, `/space/dev` via external storage
