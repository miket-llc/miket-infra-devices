# RDP Group Policy Configuration Fix

## Problem
RDP toggle in Windows Settings reverts to "Off" immediately after being enabled, even after upgrading to Windows Pro. This is caused by Group Policy settings that override manual configurations.

## Solution
Configure RDP via Group Policy registry settings in addition to standard registry settings. Group Policy settings take precedence and prevent the toggle from reverting.

## Changes Made

### 1. Updated Ansible Role
**File**: `ansible/roles/remote_server_windows_rdp/tasks/main.yml`

The role now:
- Creates Group Policy registry paths
- Sets `fDenyTSConnections = 0` in Group Policy (prevents toggle from reverting)
- Sets `fDenyTSConnections = 0` in registry (fallback)
- Enables NLA via both Group Policy and registry
- Forces Group Policy update with `gpupdate /force`
- Verifies both Group Policy and registry settings

### 2. New Playbook
**File**: `ansible/playbooks/configure-windows-rdp.yml`

Dedicated playbook for configuring RDP on all Windows devices with Group Policy settings.

### 3. PowerShell Script (Direct Deployment)
**File**: `scripts/Configure-RDP-GroupPolicy.ps1`

Standalone PowerShell script that can be run directly on Windows devices to configure RDP with Group Policy settings. This is useful when Ansible connectivity is unavailable.

## Deployment Methods

### Method 1: Ansible Deployment (Recommended)

```bash
# Deploy to all Windows devices
cd /home/mdt/miket-infra-devices
./scripts/deploy-rdp-windows.sh

# Deploy to specific device
./scripts/deploy-rdp-windows.sh armitage
./scripts/deploy-rdp-windows.sh wintermute
```

Or directly:
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml --limit armitage
```

### Method 2: Direct PowerShell Script (Fallback)

If Ansible connectivity is unavailable, run the PowerShell script directly on the Windows device:

1. Copy `scripts/Configure-RDP-GroupPolicy.ps1` to armitage
2. Open PowerShell as Administrator
3. Run:
   ```powershell
   .\Configure-RDP-GroupPolicy.ps1
   ```

The script will:
- Configure Group Policy settings
- Configure registry settings
- Ensure RDP service is running
- Configure firewall rules for Tailscale subnet
- Verify the configuration

## Testing

### Test RDP Connectivity
```bash
# Test port connectivity
./scripts/test-rdp-connection.sh armitage

# Or manually
nc -z armitage.pangolin-vega.ts.net 3389
```

### Verify RDP is Enabled
On the Windows device:
1. Open Settings > System > Remote Desktop
2. Verify the toggle is ON and stays ON
3. Check that it doesn't revert after closing/reopening Settings

### Connect via RDP
```bash
# Linux
xfreerdp /v:armitage.pangolin-vega.ts.net:3389 /u:mdt

# Windows
mstsc /v:armitage.pangolin-vega.ts.net:3389

# macOS
# Use Microsoft Remote Desktop app
```

## Registry Keys Configured

### Group Policy (Takes Precedence)
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\fDenyTSConnections = 0`
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\WinStations\RDP-Tcp\UserAuthentication = 1`

### Registry (Fallback)
- `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections = 0`
- `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\UserAuthentication = 1`

## Firewall Configuration

RDP firewall rule is configured to:
- Allow inbound TCP connections on port 3389
- Restrict access to Tailscale subnet (100.64.0.0/10)
- Rule name: "Remote Desktop (RDP) - Tailscale"

## Troubleshooting

### RDP Toggle Still Reverts
1. Verify Group Policy settings:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fDenyTSConnections"
   ```
   Should return `0`

2. Force Group Policy update:
   ```powershell
   gpupdate /force
   ```

3. Restart the Remote Desktop service:
   ```powershell
   Restart-Service TermService
   ```

### Cannot Connect via RDP
1. Verify RDP is listening:
   ```powershell
   Get-NetTCPConnection -LocalPort 3389
   ```

2. Check firewall rules:
   ```powershell
   Get-NetFirewallRule -Name "RDP-Tailscale"
   ```

3. Verify Tailscale connectivity:
   ```powershell
   ping armitage.pangolin-vega.ts.net
   ```

## Files Modified/Created

- `ansible/roles/remote_server_windows_rdp/tasks/main.yml` - Updated with Group Policy configuration
- `ansible/playbooks/configure-windows-rdp.yml` - New playbook for RDP configuration
- `scripts/Configure-RDP-GroupPolicy.ps1` - Standalone PowerShell script
- `scripts/deploy-rdp-windows.sh` - Deployment script
- `scripts/test-rdp-connection.sh` - Connection test script

## Notes

- Group Policy settings take precedence over manual registry edits
- The `gpupdate /force` command ensures changes are applied immediately
- Firewall rules are restricted to Tailscale subnet for security
- NLA (Network Level Authentication) is enabled for enhanced security
- This configuration applies to all Windows devices in the tailnet (pangolin-vega)




