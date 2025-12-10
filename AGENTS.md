# Repository Guidelines

## Project Structure & Module Organization
- Core automation lives in `ansible/` (playbooks, inventory, roles) with device specifics under `ansible/host_vars` and shared defaults in `ansible/group_vars`.
- Per-host configs and scripts sit in `devices/<hostname>/`, while shared templates and configs land in `configs/` and `docker/`.
- Operational docs and runbooks are in `docs/` (see `docs/runbooks/` for deployment checklists). Smoke tests and helpers live in `tests/`. Generated logs and artifacts are written to `logs/` and `artifacts/` by Make targets.

## Build, Test, and Development Commands
- `make deploy-nomachine-servers` / `make deploy-nomachine-clients` – roll out or update NoMachine across servers and workstations (prompts for vault where needed).
- `make validate-nomachine`, `make test-nomachine` – validate NX deployment end-to-end; produces CSVs in `artifacts/`.
- `make deploy-nextcloud`, `make validate-nextcloud`, `make test-nextcloud` – manage the Nextcloud pure-façade stack on motoko.
- `make verify-tailscale` (or `verify-tailscale-quick`) – tailnet connectivity checks.
- Targeted playbooks: run from `ansible/` with `ansible-playbook -i inventory/hosts.yml playbooks/<playbook>.yml --limit <hostgroup>`.
- SSH prep: `./scripts/ensure_ssh_agent.sh` before any Ansible run; secrets are read locally from `/etc/ansible/.vault-pass.txt` and `.become-pass.txt` on motoko.

## Coding Style & Naming Conventions
- YAML/Ansible: 2-space indent, descriptive task names, idempotent handlers, keep host-specific overrides in `host_vars` rather than playbooks. Favor roles for reusable logic.
- Shell/PowerShell: start Bash scripts with `set -euo pipefail`; prefer explicit paths. Keep device scripts under `devices/<host>/scripts/`.
- Copyright header required on all code files: `# Copyright (c) 2025 MikeT LLC. All rights reserved.` Use `.pre-commit-config.yaml` hooks or `./scripts/add-copyright-headers.sh`.
- Naming: playbooks are kebab-case (`deploy-nextcloud.yml`); artifacts/tests use snake_case (`tests/context_smoke.py`).

## Testing Guidelines
- Primary checks are Python smoke tests in `tests/` (`context_smoke.py`, `burst_test.py`, `nomachine_smoke.py`, `nextcloud_smoke.py`). Run individually with `python3 tests/<file>.py` or via Make targets above.
- Tests emit artifacts under `artifacts/`; review those for failures. Add a new smoke test when changing service behavior, network policy, or deployment flow.
- For Ansible changes, prefer `--check` on non-destructive playbooks and validate against a non-production host group before wide rollout.

## Commit & Pull Request Guidelines
- Use short, imperative commit titles that include the scope (host, role, or playbook), e.g., `harden motoko ssh config` or `validate nomachine timers`.
- Summaries should state the change and the operational effect; note any follow-up required on target hosts.
- PRs should list: scope/hosts touched, commands run (`make validate-nomachine`, `ansible-playbook ... --check`, etc.), and screenshots/log snippets only when materially helpful. Link related runbooks or issues and update docs under `docs/` or `devices/` when behavior changes.

## Security & Configuration Tips
- Never commit secrets; vault/become passwords stay local on motoko under `/etc/ansible/`. Verify `.gitignore` before adding new secret-adjacent files.
- Use Tailscale hostnames from `ansible/inventory/hosts.yml` for connectivity; avoid embedding IPs.
- Back up configs with `make backup-configs` before invasive changes; restores pull from timestamped folders in `backups/`.
