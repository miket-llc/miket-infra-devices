# Migration Playbooks

This directory contains playbooks for the `/space` + Nextcloud migration from motoko to akira.

**Reference:** `docs/architecture/adr/ADR-0010-space-nextcloud-migration-motoko-to-akira.md`

## Playbooks

| Playbook | Purpose | Phase |
|----------|---------|-------|
| `space-migration-sync.yml` | Syncs /space from motoko to akira (bulk or delta) | Phase 1 |
| `nextcloud-stage-akira.yml` | Deploys Nextcloud on akira in "dark" mode | Phase 2 |
| `nextcloud-cutover.yml` | Coordinates the service switch from motoko to akira | Phase 3 |
| `nextcloud-rollback.yml` | Emergency rollback to motoko | Rollback |

## Execution Order

### Pre-Migration (No User Impact)

```bash
# 1. Setup /space on akira
ansible-playbook playbooks/akira/setup-space.yml --limit akira

# 2. Sync secrets to akira
ansible-playbook playbooks/secrets-sync.yml --limit akira

# 3. Bulk sync /space from motoko
ansible-playbook playbooks/migration/space-migration-sync.yml --limit motoko

# 4. Stage Nextcloud on akira
ansible-playbook playbooks/migration/nextcloud-stage-akira.yml --limit akira

# 5. Validate via tailnet
curl https://akira.pangolin-vega.ts.net:8080/status.php
```

### Cutover (Maintenance Window)

```bash
# Run the coordinated cutover
ansible-playbook playbooks/migration/nextcloud-cutover.yml

# Notify miket-infra team to update Cloudflare tunnel
```

### Post-Cutover

```bash
# After 7 days with no issues, decommission motoko Nextcloud
ansible-playbook playbooks/motoko/nextcloud-decommission.yml --limit motoko
```

### Rollback (If Needed)

```bash
# Within 7-day rollback window only
ansible-playbook playbooks/migration/nextcloud-rollback.yml
```

## Runbooks

- `docs/runbooks/SPACE_NEXTCLOUD_MIGRATION.md` - Detailed migration procedure
- `docs/runbooks/NEXTCLOUD_ROLLBACK.md` - Rollback procedure

## Requirements

- Ansible 2.15+
- Target hosts accessible via Tailscale
- Azure CLI configured for AKV access
- SSH keys between motoko and akira

