# Tailscale Device Enrollment - Standard Operating Procedure

## Overview

This runbook describes the standard procedure for enrolling devices into the miket-infra Tailscale network (pangolin-vega.ts.net) with proper SSH and connectivity settings.

## Architecture Context

### Separation of Concerns

- **miket-infra**: Controls POLICY (ACL rules, who can access what, network rules)
- **miket-infra-devices**: Controls DEVICE CONFIG (what services run on each device)

### What miket-infra Controls

| Item | Controlled By | Location |
|------|---------------|----------|
| ACL Policy | ✅ miket-infra | infra/tailscale/entra-prod/main.tf |
| SSH Rules (who can SSH where) | ✅ miket-infra | infra/tailscale/entra-prod/main.tf |
| Network rules (ports, protocols) | ✅ miket-infra | infra/tailscale/entra-prod/main.tf |
| MagicDNS enablement | ✅ miket-infra | infra/tailscale/entra-prod/main.tf |
| Enrollment key generation | ✅ miket-infra | infra/tailscale/entra-prod/main.tf |
| Device tagging (via API) | ✅ miket-infra | scripts/tailscale/tag_devices.py |

### What This Repo Controls (Device Level)

| Item | Controlled By | How to Set |
|------|---------------|------------|
| Tailscale SSH enablement | ❌ Device enrollment | `tailscale up --ssh` flag |
| Device expiry settings | ❌ Device enrollment or admin console | Enrollment key type or manual toggle |
| Device hostname | ❌ Device OS | System hostname |
| Tailscale version | ❌ Device package manager | `apt install tailscale`, etc. |

## Prerequisites

### 1. Get Enrollment Key from miket-infra

From the miket-infra repository:

```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform output -raw enrollment_key
```

Save this key securely - you'll need it for each device enrollment.

### 2. Verify ACL Policy is Deployed

Ensure the miket-infra team has deployed the latest ACL policy:

```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform plan  # Should show no changes if deployed
```

## Standard Enrollment Command

### All Devices (Linux, Windows, macOS)

```bash
tailscale up \
  --auth-key=<ENROLLMENT_KEY_FROM_MIKET_INFRA> \
  --ssh \
  --accept-dns \
  --accept-routes
```

**Flags Explained:**
- `--auth-key`: Enrollment key from miket-infra (ephemeral, 24h expiry)
- `--ssh`: **CRITICAL** - Enables Tailscale SSH server on this device
- `--accept-dns`: Accept MagicDNS configuration (`.pangolin-vega.ts.net` hostnames)
- `--accept-routes`: Accept subnet routes advertised by exit nodes

## Platform-Specific Instructions

### Linux Servers (motoko)

```bash
# 1. Install Tailscale (if not already installed)
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Enroll with SSH enabled
sudo tailscale up \
  --auth-key=<KEY> \
  --ssh \
  --accept-dns \
  --accept-routes

# 3. Verify SSH label appears in admin console
tailscale status

# 4. Test MagicDNS
ping wintermute.pangolin-vega.ts.net
```

### Windows Workstations (wintermute, armitage)

```powershell
# 1. Install Tailscale (if not already installed)
# Download from https://tailscale.com/download/windows

# 2. Open PowerShell as Administrator

# 3. Enroll with SSH enabled
tailscale up `
  --auth-key=<KEY> `
  --ssh `
  --accept-dns `
  --accept-routes

# 4. Verify status
tailscale status

# 5. Test MagicDNS
ping motoko.pangolin-vega.ts.net
```

**Note:** Windows SSH server is provided by Tailscale's built-in SSH functionality.

### macOS (count-zero)

```bash
# 1. Install Tailscale (if not already installed)
brew install tailscale
sudo tailscaled install-system-daemon

# 2. Enroll with SSH enabled
sudo tailscale up \
  --auth-key=<KEY> \
  --ssh \
  --accept-dns \
  --accept-routes

# 3. Verify status
tailscale status

# 4. Test MagicDNS
ping motoko.pangolin-vega.ts.net
```

## Post-Enrollment Verification

### 1. Check SSH Label in Admin Console

Visit https://login.tailscale.com/admin/machines

Each device should show:
- ✅ **SSH** label (green badge)
- Hostname matches device name
- Status: Connected

**If SSH label is missing:**
- Device was not enrolled with `--ssh` flag
- Re-run `tailscale up --ssh` (no need to fully re-enroll)

### 2. Verify MagicDNS Resolution

```bash
# From any device on the tailnet
ping motoko.pangolin-vega.ts.net
ping wintermute.pangolin-vega.ts.net
ping armitage.pangolin-vega.ts.net
ping count-zero.pangolin-vega.ts.net
```

All should resolve to 100.x.x.x addresses.

### 3. Test Tailscale SSH Connectivity

```bash
# From any device, SSH to any other device
ssh motoko.pangolin-vega.ts.net
ssh wintermute.pangolin-vega.ts.net
ssh armitage.pangolin-vega.ts.net
ssh count-zero.pangolin-vega.ts.net
```

**Expected behavior:**
- No password prompt (Tailscale handles authentication via ACL)
- Direct shell access
- Works based on your Entra ID identity (mike@miket.io)

### 4. Test RDP Connectivity (Windows Devices)

```bash
# From any device with RDP client
# Linux: remmina
# Windows: mstsc
# macOS: Microsoft Remote Desktop

# Connect to:
rdp://wintermute.pangolin-vega.ts.net:3389
rdp://armitage.pangolin-vega.ts.net:3389
```

### 5. Apply Device Tags (via miket-infra)

Device tags are managed by the miket-infra team via Terraform and API scripts:

```bash
# From miket-infra repo
cd ~/miket-infra
python scripts/tailscale/tag_devices.py
```

Expected tags:
- **motoko**: `tag:linux`, `tag:server`, `tag:ansible`
- **wintermute**: `tag:windows`, `tag:workstation`, `tag:gaming`
- **armitage**: `tag:windows`, `tag:workstation`, `tag:gaming`
- **count-zero**: `tag:macos`, `tag:workstation`

## Troubleshooting

### SSH Label Not Appearing

**Problem:** Device enrolled but no SSH label in admin console

**Solution:**
```bash
# Re-enable SSH without full re-enrollment
tailscale up --ssh
```

The device will reconnect with SSH enabled.

### MagicDNS Not Resolving

**Problem:** Cannot ping `device.pangolin-vega.ts.net` hostnames

**Solutions:**

1. **Check MagicDNS is enabled:**
   ```bash
   tailscale status
   # Should show: MagicDNS enabled
   ```

2. **Re-accept DNS settings:**
   ```bash
   tailscale up --accept-dns
   ```

3. **Check system DNS configuration:**
   ```bash
   # Linux
   resolvectl status
   
   # macOS
   scutil --dns
   
   # Windows
   ipconfig /all
   ```

4. **Force DNS refresh:**
   ```bash
   # Linux
   sudo systemctl restart systemd-resolved
   
   # macOS
   sudo dscacheutil -flushcache
   
   # Windows
   ipconfig /flushdns
   ```

### SSH Connection Refused

**Problem:** `ssh device.pangolin-vega.ts.net` fails with "Connection refused"

**Diagnose:**

1. **Check device has SSH label:**
   - Visit Tailscale admin console
   - Device should show green SSH badge

2. **Check ACL policy allows SSH:**
   ```json
   // In miket-infra ACL policy:
   {
     "action": "accept",
     "src": ["*"],
     "dst": ["*:22"],
   }
   ```

3. **Verify device is online:**
   ```bash
   tailscale ping device.pangolin-vega.ts.net
   ```

4. **Check Tailscale SSH is running:**
   ```bash
   # Linux/macOS
   sudo tailscale status
   
   # Windows
   tailscale status
   ```

### Device Key Expiry Disabled

**Problem:** Device shows "Expiry disabled" instead of ephemeral behavior

**Context:**
- miket-infra creates ephemeral enrollment keys (24h expiry)
- But "Expiry disabled" on a device means that device's key never expires
- This can happen if device was enrolled before Terraform setup

**Impact:**
- Not a security issue (device still requires authentication)
- Violates design intent (ephemeral = auto-cleanup when offline)
- Device won't auto-remove when offline

**Solution (Optional):**

1. **Via Admin Console:**
   - Go to device settings
   - Enable "Expire device key"

2. **Via Re-enrollment:**
   ```bash
   tailscale down
   tailscale up --auth-key=<NEW_EPHEMERAL_KEY> --ssh --accept-dns
   ```

## Emergency Procedures

### Re-enroll Device from Scratch

If device is in a bad state:

```bash
# 1. Logout from Tailscale
tailscale logout

# 2. Stop Tailscale service
# Linux:
sudo systemctl stop tailscaled

# Windows (PowerShell as Admin):
Stop-Service Tailscale

# macOS:
sudo launchctl unload /Library/LaunchDaemons/com.tailscale.tailscaled.plist

# 3. Clear state (optional, nuclear option)
# Linux:
sudo rm -rf /var/lib/tailscale

# Windows:
# Remove-Item -Recurse -Force C:\ProgramData\Tailscale

# macOS:
# sudo rm -rf /Library/Tailscale

# 4. Start service
# Linux:
sudo systemctl start tailscaled

# Windows:
Start-Service Tailscale

# macOS:
sudo launchctl load /Library/LaunchDaemons/com.tailscale.tailscaled.plist

# 5. Re-enroll with correct flags
tailscale up --auth-key=<KEY> --ssh --accept-dns --accept-routes
```

## Current Device Status

### ✅ Correctly Configured

- **motoko**: SSH enabled, ephemeral key, proper tags
- **count-zero**: SSH enabled, proper tags

### ❌ Needs Attention

- **wintermute**: Missing SSH label - needs `tailscale up --ssh`
- **armitage**: Missing SSH label - needs `tailscale up --ssh`

### Action Required

Run on wintermute:
```powershell
tailscale up --ssh --accept-dns --accept-routes
```

Run on armitage:
```powershell
tailscale up --ssh --accept-dns --accept-routes
```

## Integration with Ansible

Once devices are properly enrolled with SSH:

```bash
# From motoko (Ansible control node)
cd ~/miket-infra-devices/ansible

# Test connectivity
ansible all -m ping -i inventory/hosts.yml

# Expected: All devices return pong
```

Ansible inventory uses Tailscale MagicDNS hostnames:
- `motoko.pangolin-vega.ts.net`
- `wintermute.pangolin-vega.ts.net`
- `armitage.pangolin-vega.ts.net`
- `count-zero.pangolin-vega.ts.net`

## Reference

- **Tailscale Admin Console**: https://login.tailscale.com/admin/machines
- **miket-infra ACL Policy**: `~/miket-infra/infra/tailscale/entra-prod/main.tf`
- **Device Tags Script**: `~/miket-infra/scripts/tailscale/tag_devices.py`
- **Ansible Inventory**: `~/miket-infra-devices/ansible/inventory/hosts.yml`

## Maintenance

### Monthly Review

1. Check all devices show SSH label
2. Verify MagicDNS resolution works
3. Test SSH connectivity between devices
4. Review device tags are current
5. Check for devices with disabled expiry

### When Adding New Device

1. Get enrollment key from miket-infra team
2. Follow standard enrollment command with `--ssh` flag
3. Verify SSH label appears
4. Test MagicDNS and SSH connectivity
5. Request device tagging from miket-infra team
6. Add to Ansible inventory in this repo

## Notes

- **SSH Label is Critical**: Without it, Tailscale SSH won't work even if ACL allows it
- **Ephemeral Keys**: Enrollment keys expire in 24h, but device stays connected
- **Device Expiry**: Separate from key expiry - controls auto-cleanup when offline
- **Tags**: Applied by miket-infra team via API, not during enrollment

