# Copilot Instructions for miket-infra-devices

## Project Overview
This repo automates the **Personal Hybrid Cloud (PHC)** endpoint devices using Ansible for configuration management. It manages workstations (Linux/Windows/macOS), servers (motoko, akira), and services (LiteLLM, Nextcloud, NoMachine) across a Tailscale mesh network.

**Key subordination:** Platform-level resources (Tailscale ACLs, DNS, Entra ID apps, Azure Key Vault provisioning, Cloudflare Access) are owned by `miket-infra` (Terraform/Terragrunt). This repo consumes those contracts via Ansible automation.

## Architecture Foundations

### Canonical Documents (read these first)
1. **`docs/architecture/PHC_VNEXT_ARCHITECTURE.md`** - System-wide principles (Entra-first identity, Tailscale mesh, zero-trust ingress)
2. **`docs/architecture/Miket_Infra_Devices_Architecture.md`** - Device roles, automation layers, monitoring (Netdata Cloud), IaC/CaC boundary
3. **`docs/architecture/FILESYSTEM_ARCHITECTURE.md`** - Flux/Space/Time storage backplane (**`/space` is the only SoR**)
4. **`docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md`** - Nextcloud as a pure façade over `/space`

**ADRs in use:**
- ADR-004: KDE Plasma is the standard Linux desktop for all UI nodes
- ADR-005: Workstations use Ollama; servers use vLLM
- ADR-0010: `/space` and Nextcloud migrated from motoko → akira (Dec 2025)

### Storage Invariants (never break these)
- **`/space` is the only Source of Record (SoR)** - all data flows INTO `/space`; never mirror FROM `/space` to external clouds
- **`/flux` is the active workspace** (hot, ephemeral, local snapshots)
- **`/time` is the backup/history tier** (read-mostly, recovery)
- Ingestion: OS clouds (iCloud/OneDrive) → `/space/devices/<host>/<user>/` (one-way only, loop prevention required)
- Backups: `/space` → B2 object storage (via restic/rclone); never reverse
- UX paths: `~/{flux,space,time}` everywhere (macOS: symlinks to `~/.mkt/*`; Windows: drives `X:/S:/T:`; Linux: `/mnt/*`)

### Device Inventory
| Device | Role | OS | Key Services | Tailnet |
|--------|------|----|--------------|---------|
| **motoko** | Server/control node | Fedora | Ansible control, LiteLLM proxy, `/time` export, Netdata | motoko.pangolin-vega.ts.net |
| **akira** | Storage + AI workstation | Fedora 43 KDE | `/space` SoR (18TB WD Red), Nextcloud, vLLM, space-mirror | akira.pangolin-vega.ts.net |
| **armitage** | Workstation + Ollama | Fedora KDE | Ollama (RTX 4070), NoMachine, KDE Plasma | armitage.pangolin-vega.ts.net |
| **wintermute** | Windows workstation | Windows 11 | vLLM (RTX 4070 Super), NoMachine | wintermute.pangolin-vega.ts.net |
| **atom** | Resilience node | Fedora 43 | Battery-backed SSH foothold, minimal services | atom.pangolin-vega.ts.net |
| **count-zero** | macOS client | macOS | Mounts via autofs, OS cloud ingestion | count-zero.pangolin-vega.ts.net |

Inventory: `ansible/inventory/hosts.yml` (OS families + capability groups like `gpu_8gb`, `wol_enabled`)

## Development Workflows

### Ansible Deployment Pattern
```bash
# Standard deployment from motoko (control node)
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/<playbook>.yml --limit <host>

# Windows automation requires env vars sourced first
set -a && source /etc/ansible/windows-automation.env && set +a
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-vllm-windows.yml

# Device infrastructure (mounts + OS cloud sync)
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-devices-infrastructure.yml --tags macos
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/validate-devices-infrastructure.yml
```

**Master orchestration playbooks** (call sub-playbooks via `import_playbook`):
- `deploy-devices-infrastructure.yml` - Mounts + OS cloud sync across all clients
- `deploy-nomachine.yml` - NoMachine servers + clients fleet-wide
- `deploy-netdata.yml` - Netdata agents + Cloud claiming

### Secrets Management (Azure Key Vault → `.env` files)
**CRITICAL:** Never hardcode secrets. All automation secrets flow from AKV.

1. **Mapping:** `ansible/secrets-map.yml` defines service → env file → AKV secret names
2. **Sync:** `ansible-playbook ansible/playbooks/secrets-sync.yml --limit <host>`
3. **Usage:** Services read from synced env files (e.g., `/podman/apps/litellm/.env`, `/etc/miket/storage-credentials.env`)

Common env files:
- `/podman/apps/litellm/.env` - LiteLLM API keys (motoko)
- `/etc/miket/storage-credentials.env` - B2/restic credentials (akira, motoko)
- `/etc/ansible/windows-automation.env` - WinRM passwords (motoko)
- `~/.mkt/mounts.env` - SMB passwords (macOS group)

**1Password is for humans only**; never wire automation to `op` CLI sessions.

### Testing & Validation
```bash
# Smoke tests (from repo root)
make test-context          # Context window tests (LiteLLM)
make test-burst            # Burst load tests (vLLM)
make test-nomachine        # NoMachine connectivity

# Python tests
python3 tests/nextcloud_smoke.py
python3 tests/burst_test.py

# Validation playbooks
ansible-playbook ansible/playbooks/validate-devices-infrastructure.yml
ansible-playbook ansible/playbooks/validate-mount-infrastructure.yml
ansible-playbook ansible/playbooks/validate-nextcloud.yml
```

### Runbooks & Troubleshooting
- **Runbooks:** `docs/runbooks/` (operational procedures, NOT architectural decisions)
- **Communications log:** `docs/communications/COMMUNICATION_LOG.md` (dated decisions, architecture changes, migration logs)
- **Status tracking:** `docs/product/STATUS.md` (service health dashboard)

Key runbooks:
- `devices-infrastructure-deployment.md` - Mount + sync deployment guide
- `SPACE_NEXTCLOUD_MIGRATION.md` - Migration from motoko → akira
- `LLM_WORKSTATION_USAGE_AND_TROUBLESHOOTING.md` - Ollama/vLLM operations

## Project-Specific Conventions

### Ansible Role Structure
```
ansible/roles/<role_name>/
├── defaults/main.yml          # Default variables (override in host_vars)
├── tasks/main.yml             # Entry point (includes subtasks)
├── tasks/<subtask>.yml        # Modular task files
├── templates/*.j2             # Jinja2 templates
├── files/                     # Static files to copy
└── README.md                  # Role-specific documentation
```

**Common patterns:**
- Roles use `include_tasks` for modularity (see `secrets_sync`, `headless_fedora_server`, `llm_workstation_ollama`)
- OS-specific tasks: `when: ansible_os_family == 'RedHat'` or `ansible_system == 'Linux'`
- GPU checks: Roles validate GPU presence before deploying GPU-dependent services (fail fast with clear error)

### IaC/CaC Principles (`docs/reference/iac-cac-principles.md`)
1. **Code First, Manual Never** - All changes via Ansible; never manual edits on hosts
2. **Single Source of Truth** - Device configs in `devices/{hostname}/config.yml`, host vars in `ansible/host_vars/`
3. **Idempotency** - All playbooks/roles must be safe to re-run (use `creates`, `unless`, `changed_when: false`)
4. **Defense in Depth** - Tailscale ACL (upstream) + device firewalls (this repo)

### File Organization
- **Architecture docs:** `docs/architecture/` (canonical, slow-changing)
- **Operational docs:** `docs/runbooks/`, `docs/troubleshooting/` (procedures, fast-changing)
- **Scripts:** `scripts/` (Bootstrap scripts, diagnosis tools, one-off fixes; **not** for long-term automation)
- **Ansible:** `ansible/playbooks/`, `ansible/roles/` (reusable automation)
- **Device configs:** `devices/<hostname>/` (device-specific overrides)

### Service Deployment Pattern
Services (LiteLLM, Nextcloud, vLLM) follow this lifecycle:
1. **Storage ready:** Mount `/space` before starting containers
2. **Secrets synced:** Run `secrets-sync.yml` to render env files from AKV
3. **Container/service start:** Use systemd units with `EnvironmentFile=` pointing to synced env files
4. **Health checks:** Services write `_status.json` to `/space/devices/<hostname>/`

Systemd unit dependencies: `Requires=<mount>.mount` and `After=<mount>.mount` to ensure storage is online.

### Tailscale Integration
- Hostnames: `<device>.pangolin-vega.ts.net` (MagicDNS)
- SSH access: Tailscale SSH with ACL enforcement (no password prompts on Tailscale-capable nodes)
- Tags: `tag:server`, `tag:workstation`, `tag:macos`, `tag:gpu`, `tag:llm_node` (defined in `miket-infra` ACLs)
- Mount scripts: Always use hostnames (MagicDNS), never hardcode IPs

### Monitoring (Netdata Cloud)
- **Architecture:** Standalone agents on all nodes claimed to Netdata Cloud (Homelab subscription)
- **NO parent/child streaming** - Cloud handles aggregation and retention
- **Primary UI:** https://app.netdata.cloud (unified view, historical data, alerting)
- **Local dashboards:** `http://<hostname>.pangolin-vega.ts.net:19999` (break-glass only, bound to localhost + Tailscale IP)
- **Secrets:** Claim tokens in AKV (`netdata-cloud-claim-token`, `netdata-cloud-space-id`)
- **Deployment:** `ansible-playbook ansible/playbooks/deploy-netdata.yml`

## Common Pitfalls & Gotchas

1. **Don't mirror FROM `/space`** - `/space` is the destination, not a source for external clouds
2. **Don't skip AKV for secrets** - Hardcoded passwords will be rejected in code review
3. **Don't create new SoRs** - Services must consume `/space`; never invent alternate storage hierarchies
4. **Don't use IPs in mount scripts** - Always use MagicDNS hostnames (ACL changes may reassign IPs)
5. **Don't expose prohibited paths via Nextcloud** - External storage limited to approved `/space/mike/*` folders (no `/space/projects/**`, `/space/code/**`, `/space/dev/**`)
6. **macOS autofs loop prevention** - Use `--no-links` with rsync to avoid following symlinks back into autofs mounts
7. **Windows WinRM env vars** - Must source `/etc/ansible/windows-automation.env` before running Windows playbooks
8. **systemd mount dependencies** - Always add `Requires=` and `After=` for storage-dependent services

## Quick Reference

### Key Makefiles Targets
```bash
make help                     # Show all available targets
make deploy-nomachine-servers # Deploy NoMachine to Linux/Windows servers
make validate-nomachine       # Test NoMachine connectivity
make deploy-nextcloud         # Deploy Nextcloud stack on akira
make backup-configs           # Backup current configs before changes
```

### Common Inventory Groups
- `linux`, `windows`, `macos` - OS families
- `gpu_8gb`, `gpu_12gb` - GPU capability groups
- `wol_enabled` - Wake-on-LAN capable devices
- `netdata_nodes` - Netdata agent targets

### Device-Specific Notes
- **akira:** Runs `/space` SoR on external 18TB WD Red; Nextcloud, space-mirror, and vLLM
- **motoko:** Ansible control node (run playbooks here); LiteLLM proxy; `/time` Time Machine backups
- **armitage:** Ollama workstation (not vLLM); KDE Plasma; small Windows partition offline (Dell support only)
- **wintermute:** Windows GPU node; vLLM + NoMachine; drives X:/S:/T: for Flux/Space/Time
- **atom:** Battery-backed resilience node; minimal services; proof-of-life + SSH foothold during power failures

### Where to Find Things
- Platform decisions (ACLs, DNS, Entra): `miket-infra` repo (upstream)
- Ansible inventory: `ansible/inventory/hosts.yml`
- Secrets mapping: `ansible/secrets-map.yml`
- Device configs: `devices/<hostname>/config.yml`
- Service health: `docs/product/STATUS.md`
- Architecture changes: `docs/communications/COMMUNICATION_LOG.md`
- Bootstrap scripts: `scripts/bootstrap-*.sh` (initial setup only, not reusable automation)
- Reusable automation: `ansible/playbooks/`, `ansible/roles/`

## When Making Changes

1. **Architecture changes:** Update canonical docs in `docs/architecture/`, log decision in `COMMUNICATION_LOG.md`
2. **New secrets:** Add mapping to `ansible/secrets-map.yml`, provision in AKV (upstream), run `secrets-sync.yml`
3. **New services:** Document storage paths, prove `/space` SoR alignment, add systemd mount dependencies
4. **New devices:** Add to `ansible/inventory/hosts.yml`, create `devices/<hostname>/config.yml`, apply Tailscale tags (upstream ACL)
5. **Breaking changes:** Test with `--check` and `--diff` first; use `--limit` for phased rollout

Always validate after changes: `ansible-playbook ansible/playbooks/validate-*.yml`
