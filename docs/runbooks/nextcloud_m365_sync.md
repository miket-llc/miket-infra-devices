---
document_title: "Nextcloud M365 Sync Runbook"
author: "Codex-CA-001"
last_updated: 2025-11-28
status: Published
related_initiatives:
  - initiatives/nextcloud-deployment
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# Nextcloud M365 Sync Runbook

**Status:** Published  
**Purpose:** Troubleshooting guide for M365 → /space ingestion  
**Target:** motoko (Ubuntu 24.04.2 LTS)

---

## Overview

The M365 sync job ingests files from OneDrive and SharePoint into `/space/mike/inbox/ms365/`. This is a **ONE-WAY** sync:

```
M365 (OneDrive/SharePoint) → /space/mike/inbox/ms365/
                              ↓
                           Nextcloud mounts as /ms365
                              ↓
                           Desktop clients sync
```

**⚠️ CRITICAL:** Files are NEVER synced back to M365. This is ingestion only.

## Quick Reference

### Check Status

```bash
# Timer status
systemctl status nextcloud-m365-sync.timer

# Last run
journalctl -u nextcloud-m365-sync -n 50

# View logs
tail -100 /space/_ops/logs/nextcloud/m365-sync.log
```

### Manual Sync

```bash
# Dry run (no changes)
sudo /flux/apps/nextcloud/bin/sync-m365.sh --dry-run

# Full sync
sudo /flux/apps/nextcloud/bin/sync-m365.sh
```

### Force Restart

```bash
sudo systemctl restart nextcloud-m365-sync.timer
```

---

## Troubleshooting

### Issue: Authentication Failure

**Symptoms:**
```
rclone: failed to copy: 401 Unauthorized
ERROR: Couldn't authenticate
```

**Resolution:**

1. Check rclone config:
   ```bash
   cat /flux/apps/nextcloud/config/rclone-m365.conf
   ```

2. Verify secrets in env file:
   ```bash
   sudo cat /flux/runtime/secrets/nextcloud.env | grep M365
   ```

3. Re-authenticate rclone:
   ```bash
   rclone config reconnect m365-onedrive: --config /flux/apps/nextcloud/config/rclone-m365.conf
   ```

4. Test connectivity:
   ```bash
   rclone lsd m365-onedrive: --config /flux/apps/nextcloud/config/rclone-m365.conf
   ```

---

### Issue: Token Expired

**Symptoms:**
```
ERROR: AuthenticationExpiredError
Token refresh failed
```

**Resolution:**

The M365 OAuth token needs refresh. This typically happens after 90 days.

1. Re-run secrets sync to get fresh token:
   ```bash
   ansible-playbook playbooks/secrets-sync.yml --limit motoko
   ```

2. If token is in AKV, regenerate it:
   - Go to Azure Portal → App Registrations
   - Find the Nextcloud M365 app
   - Generate new client secret
   - Update AKV secret `m365-nextcloud-client-secret`
   - Re-run secrets sync

---

### Issue: Disk Space Full

**Symptoms:**
```
rclone: failed to copy: no space left on device
ERROR: Write failed
```

**Resolution:**

1. Check disk space:
   ```bash
   df -h /space
   ```

2. Find large files:
   ```bash
   du -sh /space/mike/inbox/ms365/* | sort -h | tail -20
   ```

3. Clean up if needed:
   ```bash
   # Move old files to archive
   find /space/mike/inbox/ms365/ -type f -mtime +90 -exec mv {} /space/mike/archive/ms365/ \;
   ```

4. Resume sync:
   ```bash
   sudo systemctl start nextcloud-m365-sync
   ```

---

### Issue: Network Timeout

**Symptoms:**
```
ERROR: context deadline exceeded
Timeout waiting for response
```

**Resolution:**

1. Check network:
   ```bash
   ping -c 3 graph.microsoft.com
   ```

2. Check Tailscale:
   ```bash
   tailscale status
   ```

3. The sync script has automatic retries. Check if it recovered:
   ```bash
   journalctl -u nextcloud-m365-sync -f
   ```

---

### Issue: Files Not Appearing in Nextcloud

**Symptoms:** Files synced to `/space/mike/inbox/ms365/` but not visible in Nextcloud.

**Resolution:**

1. Trigger file scan:
   ```bash
   docker exec nextcloud-app php occ files:scan mike --path="/mike/files/ms365"
   ```

2. Check external mount:
   ```bash
   docker exec nextcloud-app php occ files_external:list | grep ms365
   ```

3. Verify permissions:
   ```bash
   ls -la /space/mike/inbox/ms365/
   # Should be owned by mdt:mdt or www-data accessible
   ```

---

### Issue: Sync Lock

**Symptoms:**
```
ERROR: Another sync is already running
```

**Resolution:**

1. Check for running process:
   ```bash
   ps aux | grep sync-m365
   ```

2. If stuck, remove lock:
   ```bash
   sudo rm /var/run/nextcloud-m365-sync.lock
   ```

3. Restart sync:
   ```bash
   sudo systemctl start nextcloud-m365-sync
   ```

---

## Configuration

### Sync Schedule

Default: Hourly (`*:00`)

To change:
```bash
# Edit timer
sudo systemctl edit nextcloud-m365-sync.timer

# Add override
[Timer]
OnCalendar=*:00/30  # Every 30 minutes
```

### Bandwidth Limits

Edit `/flux/apps/nextcloud/bin/sync-m365.sh`:

```bash
rclone copy \
    --bwlimit 10M \  # Add this line for 10MB/s limit
    ...
```

### Excluded Paths

To exclude paths from sync, edit the rclone command in `sync-m365.sh`:

```bash
rclone copy \
    --exclude "*.tmp" \
    --exclude "~$*" \
    ...
```

---

## M365 App Registration

The sync uses an Entra ID app registration:

| Setting | Value |
|---------|-------|
| Client ID | `d30c794e-e5db-40eb-978f-b2f105c0601a` |
| Tenant ID | `cd6aed39-39c7-44ec-9eeb-6eb23f6dcad0` |
| Permissions | `Files.Read.All`, `Sites.Read.All`, `User.Read.All` |

⚠️ These are READ-ONLY permissions. The sync cannot modify M365 content.

---

## Monitoring

### Prometheus Metrics (Future)

Planned metrics:
- `nextcloud_m365_sync_last_run_timestamp`
- `nextcloud_m365_sync_files_transferred`
- `nextcloud_m365_sync_bytes_transferred`
- `nextcloud_m365_sync_errors_total`

### Alerts (Future)

- Sync not run in >2 hours
- Authentication failures
- Disk space <10%

---

## Related Documentation

- [Nextcloud on Motoko](../guides/nextcloud_on_motoko.md)
- [Nextcloud Client Usage](../guides/nextcloud_client_usage.md)
- [Data Lifecycle Spec](../product/DATA_LIFECYCLE_SPEC.md)

