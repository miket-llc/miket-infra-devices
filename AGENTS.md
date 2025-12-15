# Repository Guidelines

## Project Structure & Module Organization
- `ansible/`: inventory, playbooks, and roles; host vars in `host_vars/`, shared defaults in `group_vars/`, templates inside roles.
- `devices/<hostname>/`: per-host configs and scripts (PowerShell + shell); mirror host names when adding nodes.
- `configs/` and `docker/`: shared config snippets and container assets; keep them environment-agnostic.
- `docs/`: architecture, runbooks, status/product trackers; update the matching doc when behavior changes.
- `tests/`: Python smoke/load tests; outputs land in `artifacts/`; generated backups sit in `backups/`.

## Build, Test, and Development Commands
- `make help`: list available targets and defaults.
- `make test-context` | `make test-burst` | `make test-nomachine` | `make test-nextcloud`: run smoke/load tests; inspect `artifacts/` for results.
- `make verify-tailscale` (or `verify-tailscale-quick`): tailnet connectivity checks.
- Deployment targets wrap Ansible or host scripts (`deploy-wintermute`, `deploy-armitage`, `deploy-proxy`, `deploy-nextcloud`, `deploy-nomachine-*`); prompts may request vault or host access.
- Direct Ansible use: from `ansible/`, run `ansible-playbook -i inventory/hosts.yml playbooks/<playbook>.yml --limit <group>`.

## Coding Style & Naming Conventions
- Ansible/YAML: two-space indents, descriptive task names, idempotent handlers; prefer role reuse over playbook ad-hoc tasks. Filenames kebab-case.
- Python: snake_case for files/functions, type hints, docstrings for non-trivial functions; keep modules small and in `tests/` or `scripts/`.
- Shell/PowerShell: keep shebangs (`#!/usr/bin/env ...`), set safe defaults (`set -euo pipefail` for Bash), and use host-aligned names (e.g., `Start-VLLM.ps1`).
- Copyright header on code files: `# Copyright (c) 2025 MikeT LLC. All rights reserved.`

## Testing Guidelines
- Add or adjust smoke tests in `tests/` when changing request flows, models, or deployment behavior; mirror naming (`*_smoke.py`, `*_test.py`).
- Environment overrides via `WINTERMUTE_HOST`, `ARMITAGE_HOST`, `MOTOKO_HOST`, `LITELLM_PORT`, `VLLM_PORT`.
- Before merging, run relevant `make test-*` targets; include `make verify-tailscale-quick` for networking changes. Use `ansible-playbook ... --check` when safe.

## Commit & Pull Request Guidelines
- Commits: concise, imperative subjects with optional scope prefix (`feat:`, `fix:`, `chore:`, `docs:`); explain *why* in the body when non-obvious.
- PRs: summarize intent and affected hosts/roles, list commands run, and note operational considerations (vault usage, SSH/RDP touch points). Add screenshots/logs when user-facing flows change (Nextcloud or remote UX).

## Security & Configuration Tips
- Never commit secrets; rely on `secrets-map.yml` + `secrets-sync`. Vault/become credentials live locally (e.g., `/etc/ansible/.vault-pass.txt` on motoko).
- Protect device-specific files under `devices/` and `backups/`; treat them as configuration artifacts. Validate Tailscale/Cloudflare hostnames when editing inventories or docs.
- Back up configs with `make backup-configs` before invasive changes; restores pull from timestamped folders in `backups/`.
