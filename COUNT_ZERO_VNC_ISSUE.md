# Count-Zero VNC/TigerVNC Server Issue Analysis

## Summary

**Issue**: TigerVNC server is not available from count-zero

**Root Cause**: Tailscale ACL is blocking VNC connections (port 5900) between workstations and servers.

## Current Status

### ✅ What's Working

1. **Port 5900 is listening** on count-zero
   - macOS Screen Sharing is enabled (`VNCLegacyConnectionsEnabled = 1`)
   - Port is accessible from motoko: `nc -zv count-zero.pangolin-vega.ts.net 5900` ✅

2. **Network connectivity works**
   - count-zero can connect to motoko's port 5900: `nc -zv motoko.pangolin-vega.ts.net 5900` ✅
   - ScreenSharingSubscriber process is running on count-zero

3. **Screen Sharing is enabled**
   - macOS Screen Sharing service is active
   - VNC legacy connections are enabled

### ❌ What's Not Working

**Tailscale ACL is blocking VNC connections**

The ACL rule that allows workstations to connect to servers on port 5900 needs to be applied.

## Solution

### Option 1: Apply ACL Rule via Tailscale Admin Console (Immediate)

1. Go to https://login.tailscale.com/admin/acls
2. Add this rule after the Windows RDP rule (around line 100):

```json
{
  "action": "accept",
  "src": ["tag:workstation", "tag:windows", "tag:macos"],
  "dst": ["tag:server:3389,5900", "tag:linux:3389,5900", "tag:workstation:3389,5900"]
},
```

3. Click "Save"
4. Changes take effect immediately

This allows:
- All workstations (including count-zero with `tag:workstation` and `tag:macos`) to connect via VNC (5900) to servers
- Cross-workstation remote desktop connections

### Option 2: Apply via Terraform (Proper)

```bash
cd /home/mdt/miket-infra/infra/tailscale/entra-prod

# Install Azure CLI first (if needed)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Device Tags

Current Tailscale tags:
- **motoko**: `tag:server`, `tag:linux`, `tag:ansible`
- **count-zero**: `tag:workstation`, `tag:macos`
- **armitage**: `tag:workstation`, `tag:windows`, `tag:gaming`
- **wintermute**: `tag:workstation`, `tag:windows`, `tag:gaming`

## Important Notes

1. **count-zero uses macOS Screen Sharing, not TigerVNC**
   - macOS doesn't use TigerVNC server
   - It uses built-in Screen Sharing (VNC protocol on port 5900)
   - This is the correct setup for macOS

2. **The ACL rule is documented but not applied**
   - See: `docs/TAILSCALE_ACL_VNC_UPDATE.md`
   - Status: "ACL rule added to Terraform file: ✅"
   - Status: "Needs to be applied via Terraform or admin console"

3. **Firewall is correctly configured**
   - Linux servers have UFW rules allowing port 5900 from Tailscale subnet
   - macOS firewall doesn't need explicit rules (Screen Sharing handles it)

## Verification

After applying the ACL rule, test from count-zero:

```bash
# Test connection to motoko's VNC
nc -zv motoko.pangolin-vega.ts.net 5900

# Test VNC connection (if you have a VNC client)
# macOS: open vnc://motoko.pangolin-vega.ts.net:5900
# Or use Screen Sharing app: vnc://motoko.pangolin-vega.ts.net:5900
```

## Related Files

- `docs/TAILSCALE_ACL_VNC_UPDATE.md` - ACL update documentation
- `ansible/host_vars/count-zero.yml` - count-zero VNC configuration
- `ansible/playbooks/remote_server.yml` - Remote desktop server playbook





