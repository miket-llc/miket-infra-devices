# Tailscale ACL Update for VNC/RDP Access

## Issue
Tailscale ACL is blocking VNC connections (port 5900) between workstations and servers.

## Current Tags
- motoko: `tag:server`, `tag:linux`, `tag:ansible`
- armitage: `tag:workstation`, `tag:windows`, `tag:gaming`
- wintermute: `tag:workstation`, `tag:windows`, `tag:gaming`
- count-zero: `tag:workstation`, `tag:macos`

## ACL Rule to Add

Add this rule to the Tailscale ACL (after line 100 in the current ACL):

```json
{
  "action": "accept",
  "src": ["tag:workstation", "tag:windows", "tag:macos"],
  "dst": ["tag:server:3389,5900", "tag:linux:3389,5900", "tag:workstation:3389,5900"]
},
```

This allows:
- All workstations to connect via RDP (3389) or VNC (5900) to servers
- Cross-workstation remote desktop connections

## Apply Options

### Option 1: Via Tailscale Admin Console (Immediate)
1. Go to https://login.tailscale.com/admin/acls
2. Add the rule above after the Windows RDP rule (around line 100)
3. Click "Save"
4. Changes take effect immediately

### Option 2: Via Terraform (Proper)
```bash
cd /home/mdt/miket-infra/infra/tailscale/entra-prod

# Install Azure CLI first
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Firewall Security Best Practice

**Recommendation: Keep UFW restrictive, rely on Tailscale ACL**

With Tailscale ACLs controlling access, the UFW firewall should:
1. **ALLOW** port 5900 from Tailscale subnet (`100.64.0.0/10`) - ✅ Already done
2. **DENY** port 5900 from everywhere else - ✅ Already configured as fallback

Current UFW config is correct:
```
[ 1] 5900/tcp  ALLOW IN  100.64.0.0/10  # VNC from Tailscale
```

This provides **defense in depth**:
- Layer 1: Tailscale ACL controls which devices/users can access the port
- Layer 2: UFW ensures traffic only comes from Tailscale network
- Layer 3: VNC password (motoko123) provides authentication

**Do NOT open port 5900 to the internet (0.0.0.0/0) - keep it Tailscale-only.**

## Current Status
- ACL rule added to Terraform file: ✅
- Needs to be applied via Terraform or admin console
- UFW firewall configured correctly: ✅

