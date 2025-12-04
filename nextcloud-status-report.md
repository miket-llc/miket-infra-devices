# Nextcloud Status Report
**Generated:** 2025-12-04 08:10 EST  
**Target Device:** motoko

## Summary

### ❌ Nextcloud is NOT Running

**Status:** DOWN - Containers not running

- **Service Status:** `activating` (stuck, not active)
- **Containers:** None running
- **Port 8080:** Not listening
- **Health Check:** Failing due to orphaned containers

## Issues Identified

1. **Orphaned Containers:**
   - Container names `nextcloud-db`, `nextcloud-redis`, `nextcloud-app` are in use by stopped containers
   - Cannot create new containers because names are taken
   - Containers have mount point issues preventing removal

2. **Service Timeout:**
   - `nextcloud.service` is stuck in "activating" state
   - Service times out after 300 seconds
   - Health check script is trying to recover but failing

3. **Path Mismatch:**
   - Health check script references `/podman/apps/nextcloud` 
   - Actual deployment is at `/flux/apps/nextcloud`
   - This may cause health check failures

## Current State

- **docker-compose.yml:** Exists at `/flux/apps/nextcloud/docker-compose.yml`
- **Secrets file:** Exists at `/flux/runtime/secrets/nextcloud.env`
- **Service:** `nextcloud.service` exists but not active
- **Timers:** All timers exist and are scheduled:
  - `nextcloud-m365-sync.timer` - Last run: 56min ago
  - `nextcloud-db-backup.timer` - Last run: 5h 57min ago  
  - `nextcloud-home-sweeper.timer` - Last run: 7h ago
  - `nextcloud-healthcheck.timer` - Last run: 2min 53s ago

## Recovery Steps

### Option 1: Clean Restart (Recommended)

```bash
# Stop and remove all Nextcloud containers
podman stop nextcloud-db nextcloud-redis nextcloud-app
podman rm -f nextcloud-db nextcloud-redis nextcloud-app

# Clean up orphaned containers
podman container prune -f

# Restart via systemd
systemctl restart nextcloud.service

# Check status
systemctl status nextcloud.service
podman ps | grep nextcloud
```

### Option 2: Manual Start

```bash
cd /flux/apps/nextcloud
podman compose down
podman compose up -d

# Verify
podman ps | grep nextcloud
curl http://localhost:8080/status.php
```

### Option 3: Full Redeploy

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-nextcloud.yml --limit motoko
```

## Verification

After recovery, verify:

1. **Containers running:**
   ```bash
   podman ps | grep nextcloud
   # Should show: nextcloud-app, nextcloud-db, nextcloud-redis
   ```

2. **Service active:**
   ```bash
   systemctl is-active nextcloud.service
   # Should return: active
   ```

3. **Nextcloud responding:**
   ```bash
   curl http://localhost:8080/status.php
   # Should return JSON with status
   ```

4. **Health check passing:**
   ```bash
   systemctl status nextcloud-healthcheck.service
   # Should show successful execution
   ```

## Root Cause Analysis

The containers appear to have stopped unexpectedly (possibly during a system restart or podman update), leaving orphaned containers that prevent new ones from starting. The systemd service is trying to start them but timing out, likely because:

1. Orphaned containers block name reuse
2. Health check script has path issues
3. Service timeout (300s) may be insufficient for image pulls

## Recommendations

1. **Fix health check script path:**
   - Update template to use correct path (`/flux/apps/nextcloud` not `/podman/apps/nextcloud`)

2. **Add container cleanup to service:**
   - Add `ExecStartPre` to remove orphaned containers before starting

3. **Increase service timeout:**
   - Current 300s may be insufficient for image pulls on slow connections

4. **Monitor container health:**
   - Ensure health check timer is working properly
   - Add alerts for container failures



