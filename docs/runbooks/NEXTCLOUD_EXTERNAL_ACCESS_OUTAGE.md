# Nextcloud External Access Outage Runbook

## Overview

This runbook covers diagnosis and recovery when external access to Nextcloud via `nextcloud.miket.io` is down, but internal access via Tailscale may still work.

## Architecture Reference

```
External: Internet → Cloudflare Access → cloudflared (motoko) → akira:8080 (Nextcloud)
                                                 ↓
                                        Tailscale MagicDNS
                                     (akira.pangolin-vega.ts.net)

Internal: Tailnet device → akira.pangolin-vega.ts.net:8080 (Nextcloud)
```

**Key Components:**
- DNS: `nextcloud.miket.io` → Cloudflare proxy → tunnel CNAME
- Tunnel: `motoko-phc` (b8073aa7-29ce-4bd9-8e9a-186ba69575b3) on motoko
- cloudflared: Systemd service on motoko, proxies to akira via Tailscale
- Nextcloud: Podman containers on akira, port 8080

## Quick Diagnosis Checklist

### 1. Check External Path
```bash
# DNS resolution (should show Cloudflare IPs like 104.21.x.x or 172.67.x.x)
dig +short nextcloud.miket.io

# External probe (expect 302 to Cloudflare Access login)
curl -sS -I https://nextcloud.miket.io/status.php | head -10
```

### 2. Check Internal Path (via Tailscale)
```bash
# Nextcloud health (should return JSON with installed:true)
curl -sS http://akira.pangolin-vega.ts.net:8080/status.php
```

### 3. Check Tunnel Connector (motoko)
```bash
# Via Tailscale SSH
tailscale ssh root@motoko "systemctl status cloudflared"

# Check logs
tailscale ssh root@motoko "journalctl -u cloudflared -n 50"
```

### 4. Check Nextcloud Containers (akira)
```bash
# Via Tailscale SSH (if SSH available)
tailscale ssh root@akira "podman ps | grep nextcloud"

# Or via standard SSH
ssh mdt@akira "podman ps | grep nextcloud"
```

## Common Failure Modes

### Failure Mode 1: cloudflared Not Running on motoko

**Symptoms:**
- External returns Cloudflare 520/521/522 errors OR Access login never redirects to origin
- Internal path works (`curl http://akira.pangolin-vega.ts.net:8080/status.php` returns healthy)

**Root Cause:**
- systemd service `cloudflared` is stopped or failed
- Tunnel credentials expired or missing
- motoko rebooted without cloudflared enabled

**Recovery:**
```bash
# Check status
tailscale ssh root@motoko "systemctl status cloudflared"

# Start if stopped
tailscale ssh root@motoko "systemctl start cloudflared"

# Enable for reboot persistence
tailscale ssh root@motoko "systemctl enable cloudflared"

# Verify tunnel connected (look for "Registered tunnel connection")
tailscale ssh root@motoko "journalctl -u cloudflared -n 20"
```

If cloudflared isn't installed, run the Ansible playbook:
```bash
cd ~/dev/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/deploy-cloudflared.yml
```

### Failure Mode 2: Nextcloud Containers Down on akira

**Symptoms:**
- Both external AND internal paths return connection refused/timeout
- motoko cloudflared logs show "connection refused" to akira:8080

**Recovery:**
```bash
# Check containers
tailscale ssh root@akira "podman ps -a | grep nextcloud"

# Start nextcloud stack
tailscale ssh root@akira "systemctl start nextcloud"

# Or via podman compose
tailscale ssh root@akira "cd /flux/apps/nextcloud && podman compose up -d"
```

### Failure Mode 3: Tailscale Connectivity (motoko → akira)

**Symptoms:**
- cloudflared running but logs show connection errors to akira
- `tailscale status` shows akira offline or relay-only

**Recovery:**
```bash
# Check Tailscale status
tailscale status

# Test connectivity
ping akira.pangolin-vega.ts.net

# Restart Tailscale if needed
tailscale ssh root@motoko "systemctl restart tailscaled"
```

### Failure Mode 4: DNS/Cloudflare Configuration

**Symptoms:**
- DNS doesn't resolve or points to wrong target
- Cloudflare Access app misconfigured

**Recovery:**
- Check miket-infra Terraform state for `cloudflare_record.tunnel_cnames`
- Verify tunnel ID in DNS matches active tunnel
- Check Cloudflare Access app policies in dashboard

## Post-Recovery Verification

```bash
# 1. External path (expect 302 to Access login)
curl -sS -I https://nextcloud.miket.io/status.php | head -5

# 2. Internal path (expect healthy JSON)
curl -sS http://akira.pangolin-vega.ts.net:8080/status.php

# 3. WebDAV endpoint (expect 401 - requires auth)
curl -sS -o /dev/null -w "HTTP %{http_code}\n" \
  http://akira.pangolin-vega.ts.net:8080/remote.php/dav/
```

## Prevention Measures

1. **cloudflared on motoko:**
   - Ensure `Restart=always` in systemd unit
   - Enable service: `systemctl enable cloudflared`

2. **Nextcloud on akira:**
   - Ensure systemd unit enabled: `systemctl enable nextcloud`
   - Monitor container health via Prometheus/Grafana

3. **Monitoring:**
   - Blackbox probe for `https://nextcloud.miket.io` (external)
   - Blackbox probe for `http://akira:8080/status.php` (internal)
   - Alert on 5xx errors or unavailability

## Related Documentation

- [ADR-0010: Nextcloud Migration to Akira](/docs/architecture/adr-logs/ADR-0010-nextcloud-akira-migration.md)
- [deploy-cloudflared.yml](/ansible/playbooks/motoko/deploy-cloudflared.yml)
- [akira-deploy-nextcloud.yml](/ansible/playbooks/akira-deploy-nextcloud.yml)
- [NEXTCLOUD_ROLLBACK.md](/docs/runbooks/NEXTCLOUD_ROLLBACK.md)

## Incident History

### 2025-12-17: External Access Outage

**Root Cause:** After Nextcloud migration from motoko to akira (ADR-0010), the Cloudflare tunnel remained pointed at motoko but cloudflared was not deployed. The tunnel connector was missing entirely.

**Resolution:** Deployed cloudflared on motoko with config proxying to akira via Tailscale:
```yaml
ingress:
  - hostname: nextcloud.miket.io
    service: http://akira.pangolin-vega.ts.net:8080
```

**Prevention:** Updated ansible playbook to codify the fix. Added this runbook.
