# Armitage Connectivity Troubleshooting

## Current Status

From `tailscale status`:
```
100.72.64.90   armitage   tagged-devices   windows   active; relay "iad"; offline, last seen 1h ago
```

**Issue:** Armitage is showing as **offline** in Tailscale, which prevents:
- Ansible/WinRM access (port 5985)
- Ping connectivity
- All network access from motoko

## Root Cause Analysis

### Not an ACL Issue
This is **NOT** an ACL problem in miket-infra. The ACL rules should already allow:
- `tag:ansible` (motoko) → `*:5985` (WinRM on Windows devices)

### Actual Issue: Tailscale Client Offline
Armitage's Tailscale client is not connected or is offline.

## What to Check

### 1. On Armitage (Check Tailscale Status)

```powershell
# Check if Tailscale is running
Get-Service Tailscale

# Check Tailscale status
tailscale status

# Check if connected
tailscale ping motoko.pangolin-vega.ts.net
```

### 2. Verify Tailscale Client

```powershell
# Check Tailscale process
Get-Process tailscale -ErrorAction SilentlyContinue

# Check Tailscale adapter
Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Tailscale*" }
```

### 3. Restart Tailscale (if needed)

```powershell
# Restart Tailscale service
Restart-Service Tailscale

# Or restart via GUI
# Right-click Tailscale icon in system tray → Exit → Restart
```

## If ACL Rules Need Verification

If Tailscale is connected but still can't access, check miket-infra ACL:

**File:** `miket-infra/infra/tailscale/entra-prod/devices.tf` or `main.tf`

**Required ACL rule:**
```hcl
{
  action = "accept"
  src    = ["tag:ansible"]  # motoko
  dst    = ["tag:windows:5985,5986"]  # WinRM ports
}
```

**To verify/deploy:**
```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform plan
terraform apply  # If changes needed
```

## Quick Fix Steps

1. **On armitage:** Ensure Tailscale is running and connected
2. **Verify:** `tailscale status` should show armitage as "online"
3. **Test:** From motoko, `ping armitage.pangolin-vega.ts.net` should work
4. **Deploy:** Once connectivity is restored, run the deployment playbook

## Expected ACL Configuration

The miket-infra repo should have this rule (or similar):

```hcl
# Allow Ansible (motoko) to manage Windows devices via WinRM
{
  action = "accept"
  src    = ["tag:ansible"]
  dst    = ["tag:windows:5985,5986"]  # WinRM HTTP/HTTPS
}
```

If this rule doesn't exist or is incorrect, it needs to be added/fixed in:
- `miket-infra/infra/tailscale/entra-prod/devices.tf` OR
- `miket-infra/infra/tailscale/entra-prod/main.tf`

Then deploy with:
```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform apply
```



