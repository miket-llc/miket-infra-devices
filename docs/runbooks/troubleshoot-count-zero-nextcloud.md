# Troubleshoot Nextcloud Connection on count-zero

**Issue:** Nextcloud client connection lost on count-zero (macOS)

**Status:** ACTIVE  
**Target:** count-zero (macOS workstation)  
**Owner:** Infrastructure Team

---

## Quick Diagnosis

### Option 1: Run Diagnostic Script (Recommended)

From motoko:
```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/diagnose-nextcloud-client.yml --limit count-zero
```

### Option 2: Manual Diagnostic Steps

**On count-zero, run these checks:**

```bash
# 1. Check if Nextcloud app is installed
test -d /Applications/Nextcloud.app && echo "✅ App installed" || echo "❌ App missing"

# 2. Check if Nextcloud process is running
ps aux | grep -i nextcloud | grep -v grep && echo "✅ Process running" || echo "❌ Process not running"

# 3. Check Nextcloud config directory
ls -la ~/Library/Preferences/Nextcloud/ && echo "✅ Config exists" || echo "❌ Config missing"

# 4. Check sync root directory
test -d ~/nc && echo "✅ Sync root exists" || echo "❌ Sync root missing"

# 5. Test server connectivity (try both URLs)
curl -I https://motoko.pangolin-vega.ts.net 2>&1 | head -1  # Tailscale URL
curl -I https://nextcloud.miket.io 2>&1 | head -1          # Cloudflare URL

# 6. Check Tailscale connectivity
tailscale status | grep -q "online" && echo "✅ Tailscale online" || echo "❌ Tailscale offline"
```

---

## Server-Side Issues (HTTP 500 Errors)

**Symptoms:**
- Client connects but receives HTTP 500 errors
- Health checks failing
- Container shows as "unhealthy"
- Logs show repeated 500 errors

**This is a server-side issue on motoko, not a client configuration problem.**

**Diagnosis:**
```bash
# On motoko, check Nextcloud status
docker exec nextcloud-app php occ status

# Check container health
docker ps | grep nextcloud

# Check logs for errors
docker logs nextcloud-app --tail 50 | grep -i error
```

**Common Causes:**
1. **Database connection issues** (most common)
   - Error: `could not translate host name "nextcloud-db" to address`
   - Docker network DNS resolution failure
2. Redis connection issues
3. File permission problems
4. Configuration errors

**Fix for Database Connection Issues:**
```bash
# On motoko, check database container
docker ps | grep nextcloud-db

# Check if containers are on same network
docker network inspect nextcloud-net | grep -A 5 nextcloud

# Restart Nextcloud stack (fixes network issues)
sudo systemctl restart nextcloud

# Or via docker compose
cd /flux/apps/nextcloud
sudo docker compose down
sudo docker compose up -d

# Verify database connectivity
docker exec nextcloud-app ping -c 2 nextcloud-db

# Check if it recovers
docker ps | grep nextcloud
docker logs nextcloud-app --tail 20
```

**If database container is missing:**
```bash
# Recreate the entire stack
cd /flux/apps/nextcloud
sudo docker compose down -v  # WARNING: removes volumes
sudo docker compose up -d

# Or redeploy via Ansible
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/motoko/deploy-nextcloud.yml --limit motoko
```

**Automatic Recovery:**
Starting 2025-11-30, Nextcloud has automatic health monitoring and recovery:
- Timer runs every 5 minutes (`nextcloud-healthcheck.timer`)
- Detects database connectivity failures (podman DNS race condition)
- Auto-restarts stack on failure
- Post-start validation ensures connectivity before service is "ready"

**Manual Health Check:**
```bash
# On motoko, run manual health check
/podman/apps/nextcloud/bin/nextcloud-healthcheck.sh check

# Force recovery if needed
/podman/apps/nextcloud/bin/nextcloud-healthcheck.sh recover

# Check timer status
systemctl status nextcloud-healthcheck.timer
```

If issues persist, see: [Nextcloud on Motoko Guide](../guides/nextcloud_on_motoko.md#troubleshooting)

---

## Common Issues and Fixes

### 1. Server URL Configuration

**Important:** Nextcloud supports TWO endpoints:

| Endpoint | URL | Use Case |
|----------|-----|----------|
| **Tailscale (Internal)** | `https://motoko.pangolin-vega.ts.net` | Devices on Tailscale network (preferred for tailnet devices) |
| **Cloudflare (External)** | `https://nextcloud.miket.io` | External access via Cloudflare Access |

**For count-zero (on Tailscale):** Use `https://motoko.pangolin-vega.ts.net` for direct tailnet access.

**Symptoms:**
- Nextcloud client shows disconnected or connection errors
- Cannot authenticate or sync
- Connection timeout or HTTP 500 errors

**Fix:**
```bash
# On count-zero, update the server URL in Nextcloud client:
# 1. Click Nextcloud icon in menu bar
# 2. Click "Settings" or gear icon
# 3. Click "Account" tab
# 4. Click "Remove account" or "Log out"
# 5. Click "Add account" or "Log in to your Nextcloud"
# 6. Enter: https://motoko.pangolin-vega.ts.net (for Tailscale devices)
#    OR: https://nextcloud.miket.io (for external access)
# 7. Authenticate via OIDC/Entra ID
# 8. Set sync root: ~/nc
# 9. Select folders to sync
```

**Alternative (if UI doesn't work):**
```bash
# Remove account configuration to force re-setup
rm -rf ~/Library/Preferences/Nextcloud/nextcloud.cfg
rm -rf ~/Library/Application\ Support/Nextcloud/nextcloud.cfg

# Restart Nextcloud
killall Nextcloud 2>/dev/null
open -a Nextcloud
# Follow setup wizard with correct URL: https://nextcloud.miket.io
```

---

### 2. Nextcloud App Not Running

**Symptoms:**
- No Nextcloud icon in menu bar
- `ps aux | grep nextcloud` shows nothing
- Sync stopped

**Fix:**
```bash
# On count-zero, launch Nextcloud
open -a Nextcloud

# Or if not in Applications:
/Applications/Nextcloud.app/Contents/MacOS/Nextcloud &
```

**Verify:**
- Check menu bar for Nextcloud icon
- Click icon to see sync status

---

### 2. Authentication Lost / Session Expired

**Symptoms:**
- Nextcloud icon shows red X or disconnected status
- Client shows "Connection failed" or "Authentication error"
- Cannot access server

**Fix:**
```bash
# On count-zero, reconnect manually:
# 1. Click Nextcloud icon in menu bar
# 2. Click "Settings" or "Account settings"
# 3. Click "Log out" if logged in
# 4. Click "Log in to your Nextcloud"
# 5. Enter: https://nextcloud.miket.io
# 6. Authenticate via Cloudflare Access (Entra ID)
```

**Alternative (via command line):**
```bash
# Remove account configuration (forces re-login)
rm -rf ~/Library/Preferences/Nextcloud/nextcloud.cfg
rm -rf ~/Library/Application\ Support/Nextcloud/nextcloud.cfg

# Restart Nextcloud
killall Nextcloud 2>/dev/null
open -a Nextcloud
```

---

### 3. Network Connectivity Issues

**Symptoms:**
- Cannot reach `https://nextcloud.miket.io`
- Connection timeout errors
- Tailscale offline

**Fix:**

**3a. Check Tailscale:**
```bash
# On count-zero
tailscale status

# If offline, restart Tailscale:
sudo launchctl unload /Library/LaunchDaemons/com.tailscale.tailscaled.plist 2>/dev/null
sudo launchctl load /Library/LaunchDaemons/com.tailscale.tailscaled.plist

# Wait a few seconds, then check:
tailscale status
```

**3b. Test Server Connectivity:**
```bash
# Test DNS resolution
host nextcloud.miket.io

# Test HTTPS connection
curl -v https://nextcloud.miket.io 2>&1 | grep -E "(Connected|HTTP|SSL)"

# Test from motoko (if accessible)
ssh mdt@motoko 'curl -I https://nextcloud.miket.io'
```

**3c. Check Cloudflare Tunnel:**
```bash
# On motoko, check if Cloudflare tunnel is running
ssh mdt@motoko 'systemctl status cloudflared || docker ps | grep cloudflared'
```

---

### 4. Configuration Corrupted

**Symptoms:**
- Nextcloud starts but shows errors
- Sync folder path incorrect
- Settings missing

**Fix:**
```bash
# On count-zero, backup and reset config
mkdir -p ~/Library/Preferences/Nextcloud.backup
cp -r ~/Library/Preferences/Nextcloud/* ~/Library/Preferences/Nextcloud.backup/ 2>/dev/null

# Remove corrupted config
rm -rf ~/Library/Preferences/Nextcloud/nextcloud.cfg

# Restart Nextcloud (will prompt for re-setup)
killall Nextcloud 2>/dev/null
open -a Nextcloud
```

**Reconfigure:**
1. Enter server: `https://nextcloud.miket.io`
2. Authenticate via Cloudflare Access
3. Set sync root: `~/nc`
4. Select folders to sync: `work`, `media`, `finance`, `inbox`, `assets`, `camera`

---

### 5. Sync Root Directory Issues

**Symptoms:**
- Sync root (`~/nc`) missing or inaccessible
- Permission errors
- Files not syncing

**Fix:**
```bash
# On count-zero, recreate sync root
mkdir -p ~/nc
chmod 755 ~/nc

# Verify ownership
ls -ld ~/nc
# Should show: drwxr-xr-x  miket  staff  ...

# If wrong owner, fix:
chown -R miket:staff ~/nc
```

---

### 6. Nextcloud App Not Installed

**Symptoms:**
- `/Applications/Nextcloud.app` doesn't exist
- Cannot launch Nextcloud

**Fix:**

**Option A: Install via Homebrew (automated)**
```bash
# From motoko, redeploy client
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-nextcloud-client.yml --limit count-zero
```

**Option B: Install manually**
```bash
# On count-zero
brew install --cask nextcloud

# Or download from:
# https://nextcloud.com/install/#install-clients
```

---

## Full Reset Procedure

If nothing else works, perform a full reset:

```bash
# On count-zero

# 1. Stop Nextcloud
killall Nextcloud 2>/dev/null

# 2. Backup existing data
mkdir -p ~/nc.backup
cp -r ~/nc/* ~/nc.backup/ 2>/dev/null

# 3. Remove all Nextcloud configuration
rm -rf ~/Library/Preferences/Nextcloud/
rm -rf ~/Library/Application\ Support/Nextcloud/
rm -rf ~/Library/Caches/Nextcloud/

# 4. Reinstall via Ansible (from motoko)
# ssh mdt@motoko
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-nextcloud-client.yml --limit count-zero

# 5. On count-zero, launch and reconfigure
open -a Nextcloud
# Follow setup wizard:
# - Server: https://nextcloud.miket.io
# - Auth: Cloudflare Access (Entra ID)
# - Sync root: ~/nc
# - Folders: work, media, finance, inbox, assets, camera
```

---

## Verification Steps

After fixing, verify connection:

```bash
# 1. Check Nextcloud is running
ps aux | grep -i nextcloud | grep -v grep

# 2. Check menu bar icon (should show green checkmark when synced)

# 3. Test sync by creating a file
echo "test" > ~/nc/work/test_connection.txt

# 4. Check if file appears in Nextcloud web UI
# Visit: https://nextcloud.miket.io
# Navigate to: work/test_connection.txt

# 5. Check sync status in client
# Click Nextcloud menu bar icon → View sync status
```

---

## Related Documentation

- [Nextcloud Client Usage Guide](../guides/nextcloud_client_usage.md)
- [Nextcloud on Motoko](../guides/nextcloud_on_motoko.md)
- [Device Health Check Runbook](device-health-check.md)
- [Troubleshoot count-zero Space Directory](troubleshoot-count-zero-space.md)
- [Nextcloud Permissions Troubleshooting](nextcloud-permissions-troubleshooting.md) - for red icon/permission issues
- [Nextcloud Platform Contract](../reference/NEXTCLOUD_PLATFORM_CONTRACT.md)

---

## Support

If issue persists after following this guide:

1. Collect diagnostic output:
   ```bash
   # On count-zero
   ps aux | grep nextcloud > /tmp/nextcloud-process.txt
   ls -la ~/Library/Preferences/Nextcloud/ > /tmp/nextcloud-config.txt
   tail -50 ~/Library/Logs/Nextcloud/nextcloud.log > /tmp/nextcloud-logs.txt 2>/dev/null
   ```

2. Check server status (on motoko):
   ```bash
   docker ps | grep nextcloud
   docker logs nextcloud-app --tail 50
   ```

3. File issue with collected diagnostics

