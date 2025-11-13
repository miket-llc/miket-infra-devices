# MagicDNS and RDP Deployment Summary

## MagicDNS Status

### ✅ Completed
1. **motoko** (100.92.23.71) - Already working, no changes needed
2. **armitage** (100.72.64.90) - Fixed via WinRM
   - Command executed: `tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming --accept-routes --accept-dns`
   - Status: ✅ Reachable and responding
3. **wintermute** (100.89.63.123) - Fixed via WinRM
   - Command executed: `tailscale up --advertise-tags=tag:workstation,tag:gaming --accept-routes --accept-dns`
   - Status: ✅ Reachable and responding

### ⚠️ Pending (Requires Local Access)
4. **count-zero** (100.111.7.19) - Needs local execution
   - SSH is not enabled/accessible
   - **Action Required:** Run this command locally on count-zero:
     ```bash
     tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
     ```
   - Location: Open a terminal on count-zero (NOT the Cursor SSH terminal) and run the command above

## RDP Configuration

### Current Status
- RDP port 3389 is timing out on both armitage and wintermute
- This could be due to:
  1. RDP not enabled
  2. Firewall rules not configured
  3. Service not running

### Recommended Actions

#### Option 1: Run PowerShell scripts directly (RECOMMENDED)
Copy these files to the Windows machines and run as Administrator:

**For armitage:**
```powershell
# In PowerShell as Administrator
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1
Start-Service -Name TermService
Set-Service -Name TermService -StartupType Automatic
New-NetFirewallRule -DisplayName "Remote Desktop (RDP) - Tailscale" -Name "RDP-Tailscale" -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress 100.64.0.0/10 -Action Allow -Enabled True -Force
```

**For wintermute:** (Same commands as above)

#### Option 2: Use existing Ansible deployment
There's an Ansible playbook at `ansible/playbooks/deploy-armitage-rdp.yml` but it needs vault password configuration fixed.

### Verification
After running the RDP commands, verify:
```powershell
# On Windows machine
Get-NetTCPConnection -LocalPort 3389 -State Listen
Test-NetConnection -ComputerName localhost -Port 3389
```

From motoko:
```bash
nc -zv armitage.pangolin-vega.ts.net 3389
nc -zv wintermute.pangolin-vega.ts.net 3389
```

## VNC Status
VNC was not configured during this session. Standard VNC ports (5900) were not tested.

## Files Created
- `devices/armitage/scripts/Fix-MagicDNS-Now.ps1`
- `devices/wintermute/scripts/Fix-MagicDNS-Now.ps1`
- `devices/count-zero/fix-magicdns-now.sh`
- `FIX_COUNT_ZERO_INSTRUCTIONS.md`
- `FIX_WINDOWS_DNS_COMMANDS.md`
- `ansible/playbooks/enable-rdp-simple.yml`

## Quick Test Results
```
✅ armitage hostname resolution: WORKING
✅ wintermute hostname resolution: WORKING
✅ armitage ping: WORKING
✅ wintermute ping: WORKING
❌ armitage RDP port 3389: TIMEOUT
❌ wintermute RDP port 3389: TIMEOUT
```

## Next Steps
1. **Immediate:** Run the count-zero MagicDNS fix command locally on count-zero
2. **RDP:** Run the PowerShell RDP configuration commands on both Windows machines
3. **Verify:** Test RDP connectivity after running the commands
4. **Optional:** Configure VNC if needed


