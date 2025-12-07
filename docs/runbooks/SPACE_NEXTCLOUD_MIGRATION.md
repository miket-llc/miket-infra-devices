# /space + Nextcloud Migration Runbook

**Purpose:** Migrate `/space` (System of Record) and Nextcloud PHC service from `motoko` to `akira`.

**Estimated Duration:** 4-6 hours (including sync time for ~10TB of data)  
**Maintenance Window:** ~15 minutes (Phase 3 cutover only)  
**Risk Level:** Medium  
**Rollback Available:** Yes, for 7 days post-cutover

## References

- **ADR:** `docs/architecture/adr/ADR-0010-space-nextcloud-migration-motoko-to-akira.md`
- **Architecture:** `docs/architecture/FILESYSTEM_ARCHITECTURE.md`
- **Nextcloud:** `docs/architecture/components/NEXTCLOUD_PHC_ARCHITECTURE.md`

## Prerequisites

Before starting the migration:

### Hardware
- [ ] akira's WD Red 18TB external drive is connected to USB 3.x port (rear panel)
- [ ] Drive UUID verified: `9f387c92-613e-44fb-a6c4-3878b95905f3`
- [ ] Network connectivity stable between motoko and akira (Tailscale)

### Software
- [ ] Azure CLI configured on akira with AKV access
- [ ] Podman installed on akira
- [ ] Secrets synced to akira: `ansible-playbook playbooks/secrets-sync.yml --limit akira`

### Coordination
- [ ] `miket-infra` team notified of migration window
- [ ] Users notified of potential brief service interruption

## Phase 1: /space Setup on akira

**Goal:** Mount and configure `/space` on akira with proper structure.

```bash
# From Ansible control node (motoko)
cd ~/dev/miket-infra-devices/ansible

# Step 1.1: Deploy akira_space role
ansible-playbook -i inventory/hosts.yml playbooks/akira/setup-space.yml --limit akira

# Step 1.2: Verify mount
ssh mdt@akira "mountpoint /space && ls -la /space"
```

Expected output:
```
/space is a mountpoint
drwxr-xr-x  4 root root 4096 Dec  7 12:00 .
drwxr-xr-x 20 root root 4096 Dec  7 12:00 ..
drwxr-xr-x  8 miket miket 4096 Dec  7 12:00 mike
drwxr-xr-x  2 root root 4096 Dec  7 12:00 _services
drwxr-xr-x  2 root root 4096 Dec  7 12:00 _ops
```

## Phase 2: Bulk Data Sync (Background, No User Impact)

**Goal:** Copy all data from motoko:/space to akira:/space.

**Duration:** 4-8 hours depending on data size (~10TB)

```bash
# Step 2.1: Start bulk sync (can run overnight)
ansible-playbook -i inventory/hosts.yml playbooks/migration/space-migration-sync.yml --limit motoko

# Step 2.2: Monitor progress (in another terminal)
ssh mdt@motoko "tail -f /var/log/rsync-space-migration.log"

# Step 2.3: Verify sync completed
ssh mdt@akira "du -sh /space"
ssh mdt@motoko "du -sh /space"
# Both should show similar sizes (within a few GB for ephemeral data)
```

## Phase 3: Stage Nextcloud (Dark Mode)

**Goal:** Deploy Nextcloud on akira, validate it works via tailnet before cutover.

```bash
# Step 3.1: Sync secrets to akira
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit akira

# Step 3.2: Deploy Nextcloud in dark mode
ansible-playbook -i inventory/hosts.yml playbooks/migration/nextcloud-stage-akira.yml --limit akira

# Step 3.3: Validate via tailnet
curl -I https://akira.pangolin-vega.ts.net:8080/status.php
# Expected: HTTP/1.1 200 OK

# Step 3.4: Login test (via browser)
# Open: https://akira.pangolin-vega.ts.net:8080
# Login with Entra SSO credentials
# Verify external storage mounts are visible
```

### Validation Checklist

- [ ] Nextcloud web UI loads at `https://akira.pangolin-vega.ts.net:8080`
- [ ] Entra SSO login works
- [ ] External storage folders visible: work, media, finance, assets, camera, inbox, ms365
- [ ] Files in external storage are accessible
- [ ] No Nextcloud-branded directories created under `/space`

## Phase 4: Coordinated Cutover (Maintenance Window)

**Goal:** Switch Nextcloud from motoko to akira with minimal downtime.

**Duration:** ~15 minutes

### Pre-Cutover (T-5 minutes)

```bash
# Notify users of impending maintenance
# (via Slack, email, or other channel)

# Final pre-flight check
ssh mdt@motoko "systemctl is-active nextcloud"
ssh mdt@akira "podman ps | grep nextcloud"
```

### Execute Cutover

```bash
# Run the cutover playbook (handles all steps automatically)
ansible-playbook -i inventory/hosts.yml playbooks/migration/nextcloud-cutover.yml

# Monitor output for any errors
# The playbook will:
# 1. Put motoko Nextcloud in maintenance mode
# 2. Run final delta sync
# 3. Export/import database
# 4. Start akira Nextcloud
# 5. Switch space-mirror and M365 jobs
# 6. Run smoke tests
```

### Post-Cutover Verification

```bash
# Verify akira Nextcloud is responding
curl -I https://akira.pangolin-vega.ts.net:8080/status.php

# Verify space-mirror timer is running on akira
ssh mdt@akira "systemctl status space-mirror.timer"

# Verify motoko Nextcloud is stopped
ssh mdt@motoko "systemctl status nextcloud" # Should be inactive

# Check external storage access
ssh mdt@akira "ls -la /space/mike/"
```

### Notify miket-infra Team

Send the following to the `miket-infra` team:

```
Subject: Nextcloud Migration Complete - Tunnel Update Required

Nextcloud has been migrated from motoko to akira.

Please update the Cloudflare tunnel:
- Service: nextcloud.miket.io
- New target: akira.pangolin-vega.ts.net:8080
- Health check: https://akira.pangolin-vega.ts.net:8080/status.php

Rollback available until: [cutover_date + 7 days]
```

## Phase 5: Post-Cutover Monitoring

**Duration:** 7 days (rollback window)

### Daily Checks

```bash
# Check Nextcloud health
curl -s https://nextcloud.miket.io/status.php | jq .

# Check space-mirror job status
ssh mdt@akira "journalctl -u space-mirror.service --since '24 hours ago' | tail -20"

# Check M365 sync status
ssh mdt@akira "journalctl -u nextcloud-m365-sync.service --since '24 hours ago' | tail -20"

# Check data estate markers
ssh mdt@akira "cat /space/_ops/data-estate/markers/b2_mirror.json"
ssh mdt@akira "cat /space/_ops/data-estate/markers/m365_sync.json"
```

### Success Criteria

- [ ] Nextcloud accessible via `https://nextcloud.miket.io`
- [ ] Files sync correctly from Nextcloud clients
- [ ] M365 ingestion job running every hour
- [ ] space-mirror job syncing to B2 every 4 hours
- [ ] No unexpected errors in logs
- [ ] No Nextcloud-branded directories appearing under `/space`

## Rollback Procedure

If issues are discovered within the 7-day rollback window:

```bash
# Execute rollback playbook
ansible-playbook -i inventory/hosts.yml playbooks/migration/nextcloud-rollback.yml

# Notify miket-infra team to revert tunnel
# Subject: ROLLBACK - Nextcloud returning to motoko
```

See `docs/runbooks/NEXTCLOUD_ROLLBACK.md` for detailed rollback procedure.

## Post-Rollback Window Cleanup

After 7 days with no issues:

```bash
# Decommission Nextcloud on motoko
ansible-playbook -i inventory/hosts.yml playbooks/motoko/nextcloud-decommission.yml

# This will:
# - Remove Nextcloud containers
# - Archive config and DB snapshots to /space/_services/nextcloud/archive/
# - Remove systemd units
# - Keep /space mount (now pointing to akira for other clients)
```

## Troubleshooting

### Nextcloud won't start on akira

```bash
# Check container logs
podman logs nextcloud-app

# Check database connectivity
podman exec nextcloud-db pg_isready -U nextcloud

# Verify secrets are present
ls -la /flux/runtime/secrets/nextcloud.env
```

### space-mirror job fails

```bash
# Check credentials
source /etc/miket/storage-credentials.env
echo "Key ID: $B2_APPLICATION_KEY_ID"
rclone lsd :b2:miket-space-mirror

# Check logs
journalctl -u space-mirror.service -n 100
```

### /space not mounting on akira

```bash
# Check device is connected
lsblk

# Check UUID
blkid /dev/sda1

# Manual mount attempt
mount -t btrfs -o compress=zstd:3,noatime UUID=9f387c92-613e-44fb-a6c4-3878b95905f3 /space
```

### Database restore fails

```bash
# Check PostgreSQL logs
podman logs nextcloud-db

# Connect manually
podman exec -it nextcloud-db psql -U nextcloud -d nextcloud

# List tables
\dt
```

## Contacts

- **IaC/Automation:** miket-infra-devices team
- **DNS/Tunnels:** miket-infra team
- **On-call:** Check #infra-alerts channel

