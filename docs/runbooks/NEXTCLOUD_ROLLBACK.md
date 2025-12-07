# Nextcloud Rollback Runbook

**Purpose:** Emergency rollback of Nextcloud from akira to motoko.

**When to Use:** If critical issues are discovered after the cutover to akira within the 7-day rollback window.

**Estimated Duration:** 30-60 minutes  
**Risk Level:** Medium (data written to akira since cutover needs to be preserved)

## Prerequisites

- [ ] Within 7-day rollback window (check `cutover.json` marker)
- [ ] motoko Nextcloud stack still present (containers, config, systemd units)
- [ ] Network connectivity between akira and motoko
- [ ] Coordination with `miket-infra` team for tunnel revert

## Decision Criteria

Rollback should be considered if:

1. **Data integrity issues:** Files corrupted, missing, or inaccessible
2. **Performance degradation:** Significant slowdown affecting users
3. **Service unavailability:** Nextcloud repeatedly crashing or unreachable
4. **Security concerns:** Unexpected behavior, unauthorized access

## Rollback Procedure

### Step 1: Assess Current State

```bash
# Check cutover marker for timing
ssh mdt@akira "cat /space/_ops/data-estate/markers/cutover.json"

# Check if motoko Nextcloud is still intact
ssh mdt@motoko "ls -la /flux/apps/nextcloud/"
ssh mdt@motoko "podman images | grep nextcloud"
```

### Step 2: Put akira in Maintenance Mode

```bash
# Via Ansible
ansible-playbook playbooks/migration/nextcloud-rollback.yml --tags maintenance

# Or manually
ssh mdt@akira "podman exec nextcloud-app php occ maintenance:mode --on"
```

### Step 3: Capture Changes from akira

Any files or data written to `/space` while akira was active need to be preserved.

```bash
# Create database snapshot from akira
ssh mdt@akira "podman exec nextcloud-db pg_dump -U nextcloud -d nextcloud | gzip > /space/_services/nextcloud/db-snapshots/rollback-$(date +%Y%m%d-%H%M%S).sql.gz"

# Sync /space changes back to motoko
# (Only needed if motoko will regain /space ownership)
ssh mdt@akira "rsync -avz --update /space/ mdt@motoko.pangolin-vega.ts.net:/space/"
```

### Step 4: Execute Rollback Playbook

```bash
ansible-playbook -i inventory/hosts.yml playbooks/migration/nextcloud-rollback.yml
```

The playbook will:
1. Export final state from akira
2. Sync any new data back to motoko
3. Start Nextcloud on motoko
4. Restore database
5. Enable services (M365 sync, space-mirror)
6. Stop services on akira
7. Disable maintenance mode on motoko

### Step 5: Verify motoko Nextcloud

```bash
# Check service status
ssh mdt@motoko "systemctl status nextcloud"

# Check web UI
curl -I https://motoko.pangolin-vega.ts.net:8080/status.php

# Check database
ssh mdt@motoko "podman exec nextcloud-db psql -U nextcloud -d nextcloud -c '\dt'"
```

### Step 6: Notify miket-infra Team

```
Subject: ROLLBACK - Nextcloud returning to motoko

Nextcloud is being rolled back from akira to motoko due to [reason].

Please revert the Cloudflare tunnel:
- Service: nextcloud.miket.io
- Target: motoko.pangolin-vega.ts.net:8080

Confirm when complete.
```

### Step 7: Monitor motoko

```bash
# Watch logs
ssh mdt@motoko "journalctl -u nextcloud -f"

# Check space-mirror
ssh mdt@motoko "systemctl status space-mirror.timer"

# Check M365 sync
ssh mdt@motoko "systemctl status nextcloud-m365-sync.timer"
```

## Post-Rollback Actions

### Immediate (same day)

- [ ] Confirm all users can access Nextcloud
- [ ] Verify file sync works from clients
- [ ] Check space-mirror job runs successfully
- [ ] Document rollback reason in incident report

### Within 24 Hours

- [ ] Root cause analysis of why rollback was needed
- [ ] Create issue/ticket for fix
- [ ] Determine if re-migration is possible

### Before Re-Attempting Migration

- [ ] Fix root cause
- [ ] Test fix in isolation
- [ ] Update migration playbooks if needed
- [ ] Schedule new maintenance window

## What Gets Preserved

| Data | Location | Preserved |
|------|----------|-----------|
| User files | `/space/mike/*` | ✅ Yes |
| Database | PostgreSQL dump | ✅ Yes (via snapshot) |
| Config | `/space/_services/nextcloud/config/` | ✅ Yes |
| Logs | `/space/_ops/logs/nextcloud/` | ✅ Yes |
| Container images | Podman cache | ⚠️ May need re-pull |

## What Gets Lost

- Any in-flight uploads that weren't saved
- Temporary session data
- Cache (will be rebuilt)

## Manual Rollback Steps (If Automation Fails)

If the playbook fails, execute these steps manually:

```bash
# 1. Put akira in maintenance mode
ssh mdt@akira "podman exec nextcloud-app php occ maintenance:mode --on"

# 2. Stop akira services
ssh mdt@akira "systemctl stop nextcloud space-mirror.timer nextcloud-m365-sync.timer"

# 3. Export database
ssh mdt@akira "podman exec nextcloud-db pg_dump -U nextcloud -d nextcloud | gzip > /tmp/rollback-db.sql.gz"
scp mdt@akira:/tmp/rollback-db.sql.gz /tmp/

# 4. Start motoko services
ssh mdt@motoko "podman compose -f /flux/apps/nextcloud/docker-compose.yml up -d"

# 5. Wait for database
ssh mdt@motoko "until podman exec nextcloud-db pg_isready; do sleep 2; done"

# 6. Import database
scp /tmp/rollback-db.sql.gz mdt@motoko:/tmp/
ssh mdt@motoko "gunzip -c /tmp/rollback-db.sql.gz | podman exec -i nextcloud-db psql -U nextcloud -d nextcloud"

# 7. Enable motoko services
ssh mdt@motoko "systemctl enable --now nextcloud space-mirror.timer nextcloud-m365-sync.timer"

# 8. Disable maintenance mode
ssh mdt@motoko "podman exec nextcloud-app php occ maintenance:mode --off"
```

## Contacts

- **IaC/Automation:** miket-infra-devices team
- **DNS/Tunnels:** miket-infra team (for Cloudflare revert)
- **On-call:** Check #infra-alerts channel

