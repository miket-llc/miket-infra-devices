# RDP Toggle Grayed Out - Explanation

## Status: RDP is Actually Enabled and Working ✅

When you see "Some settings are managed by your organization" and the RDP toggle is grayed out and showing "Off", this is **expected behavior** when Group Policy manages RDP. The toggle being grayed out doesn't mean RDP is disabled - it means Windows is preventing manual changes because Group Policy is controlling it.

## Verification

RDP is confirmed to be working:
- ✅ Port 3389 is open and listening
- ✅ Group Policy `fDenyTSConnections = 0` (enabled)
- ✅ Registry `fDenyTSConnections = 0` (enabled)
- ✅ Remote Desktop service is running
- ✅ Firewall rules are configured

## Why the Toggle Shows "Off"

When Group Policy manages RDP via registry settings in `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services`, Windows:
1. Grays out the toggle to prevent manual changes
2. Shows "Some settings are managed by your organization"
3. May display "Off" even though RDP is actually enabled

This is a Windows UI limitation - the Settings app doesn't always correctly reflect the actual RDP state when Group Policy is involved.

## Connecting from Other Devices

### From count-zero (macOS):
```bash
# Use Microsoft Remote Desktop app
# Or via command line:
open "rdp://armitage.pangolin-vega.ts.net:3389"
```

### From wintermute (Windows):
```powershell
# Use Remote Desktop Connection (mstsc)
mstsc /v:armitage.pangolin-vega.ts.net:3389

# Or via GUI:
# 1. Open Remote Desktop Connection
# 2. Enter: armitage.pangolin-vega.ts.net:3389
# 3. Click Connect
```

### From motoko (Linux):
```bash
# Using xfreerdp
xfreerdp /v:armitage.pangolin-vega.ts.net:3389 /u:mdt

# Or using rdesktop
rdesktop armitage.pangolin-vega.ts.net:3389 -u mdt
```

## Troubleshooting Connection Issues

If you can't connect from count-zero or wintermute:

1. **Verify Tailscale connectivity:**
   ```bash
   # From count-zero or wintermute
   ping armitage.pangolin-vega.ts.net
   ```

2. **Check firewall rules on armitage:**
   ```powershell
   Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*Remote Desktop*" -or $_.DisplayName -like "*RDP*" } | Select-Object DisplayName, Enabled
   ```

3. **Test port connectivity:**
   ```bash
   # From count-zero or wintermute
   nc -zv armitage.pangolin-vega.ts.net 3389
   ```

4. **Verify RDP is listening:**
   ```powershell
   # On armitage
   Get-NetTCPConnection -LocalPort 3389
   ```

## How to Verify RDP is Actually Enabled

Even though the toggle shows "Off", you can verify RDP is enabled:

### Method 1: Check Registry (PowerShell on armitage)
```powershell
$gp = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fDenyTSConnections"
Write-Output "Group Policy fDenyTSConnections: $($gp.fDenyTSConnections)"
# Should show: 0 (0 = enabled, 1 = disabled)
```

### Method 2: Check if Port is Listening
```powershell
# On armitage
Get-NetTCPConnection -LocalPort 3389
# Should show port 3389 in LISTEN state
```

### Method 3: Test Connection
```bash
# From any device on Tailscale
nc -zv armitage.pangolin-vega.ts.net 3389
# Should show: Connection succeeded
```

## If You Need to Change the Toggle Display

If you want the toggle to be interactive (not grayed out), you would need to:
1. Remove the Group Policy registry settings
2. Use only standard registry settings

However, this would allow the toggle to revert, which is the original problem we're solving.

**Recommendation:** Keep Group Policy management enabled. The grayed-out toggle is a small UI inconvenience for the benefit of having RDP stay enabled consistently.

## Summary

- ✅ RDP is enabled and working
- ✅ Port 3389 is accessible
- ✅ Group Policy is correctly configured
- ⚠️  Toggle is grayed out (expected when Group Policy manages it)
- ⚠️  Toggle may show "Off" (Windows UI limitation)

**The grayed-out toggle does NOT mean RDP is disabled.** RDP is working correctly and can be accessed from other devices on your Tailscale network.




