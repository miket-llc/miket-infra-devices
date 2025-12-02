# Netdata Cloud Connectivity Troubleshooting - Resolution Summary

**Date:** 2025-12-02  
**Incident:** Windows hosts (wintermute, armitage) appeared offline in Netdata Cloud

## Executive Summary

✅ **RESOLVED** - Both Windows hosts are now online and connected to Netdata Cloud.

## Root Cause

1. **Wintermute's service was stopped** - The service was not running when investigation began
2. **netdatacli command hanging issue** - The `netdatacli aclk-state` command would hang when called directly via Ansible, creating the false impression that ACLK was stuck

## Current Status

### All Hosts - Online and Connected

| Host | OS | ACLK Status | Last Connection | Claimed ID |
|------|----|-----------:|----------------|------------|
| motoko | Linux (Fedora) | ✅ Online | Active | b4e5d68d-e9c7-4b1c-bf7d-debe5f88e60d |
| atom | Linux (Fedora) | ✅ Online | Active | db665f6e-f422-49bb-b054-f4f0ba275f39 |
| wintermute | Windows 11 | ✅ Online | 2025-12-02 16:58:21 | 988722eb-be35-5945-b757-3007fc7fda33 |
| armitage | Windows 11 | ✅ Online | 2025-12-02 16:58:35 | ecd400c7-df95-3f41-a9f2-fc1a51382c29 |

### Wintermute Details
```
ACLK Available: Yes
Online: Yes
Claimed: Yes
Reconnect count: 0
Banned By Cloud: No
Publish Latency: 11ms 444us
```

### Armitage Details
```
ACLK Available: Yes
Online: Yes
Claimed: Yes
Reconnect count: 0
Banned By Cloud: No
Publish Latency: 12ms 181us
```

## Actions Taken

1. ✅ Restarted Netdata service on wintermute (was stopped)
2. ✅ Restarted Netdata service on armitage (was running, restarted as precaution)
3. ✅ Verified claim configuration exists at `C:\Program Files\Netdata\var\lib\netdata\cloud.d\`
4. ✅ Verified Windows Firewall allows outbound HTTPS (port 443)
5. ✅ Confirmed connectivity to app.netdata.cloud from both hosts
6. ✅ Verified ACLK online status via API and netdatacli

## Technical Findings

### Claim Configuration Location (Windows)
- **Correct path:** `C:\Program Files\Netdata\var\lib\netdata\cloud.d\cloud.conf`
- **NOT** at: `C:\Program Files\Netdata\etc\netdata\claim.d\` (this directory doesn't exist)

### Required Files (Present on Both Hosts)
```
cloud.d/
├── claimed_id     (36 bytes)
├── cloud.conf     (~395 bytes)
├── private.pem    (~1700 bytes)
└── public.pem     (~451 bytes)
```

### Network Connectivity
- ✅ Port 443 outbound to app.netdata.cloud: **Working**
- ✅ DNS resolution for app.netdata.cloud: **Working** (resolves to 104.20.22.2)
- ✅ Windows Firewall: **Enabled but not blocking**

### netdatacli Workaround
Direct calls to `netdatacli.exe aclk-state` can hang. Use PowerShell jobs with timeout:

```powershell
$job = Start-Job -ScriptBlock { 
    & 'C:\Program Files\Netdata\usr\bin\netdatacli.exe' aclk-state 2>&1 
}
Wait-Job $job -Timeout 10 | Out-Null
if ($job.State -eq 'Completed') { 
    Receive-Job $job 
} else { 
    Stop-Job $job
    Write-Output 'Command timed out'
}
Remove-Job $job -Force
```

Or use API query:
```powershell
(Invoke-WebRequest -Uri 'http://localhost:19999/api/v1/info' -UseBasicParsing).Content | ConvertFrom-Json
```

## Outstanding Questions

### Why did wintermute's service stop?

**Investigation Results:**
- Windows Event Viewer shows service was installed on 2025-12-01 21:24:23
- No crash events or errors found in System or Application logs
- Service log shows clean stop/start cycles (21:48, 21:54, 21:58) - these were manual restarts during troubleshooting
- **Likely cause:** Manual stop or Windows Update

**Recommendation:** Monitor the service over the next few days to see if it stops again. If it does, enable more verbose logging.

## Monitoring Commands

### Check All Hosts (Ansible)
```bash
# Linux hosts
cd /home/mdt/dev/miket-infra-devices/ansible
ansible linux -m shell -a "netdatacli aclk-state | grep -E 'ACLK Available|Online|Claimed'" --one-line

# Windows hosts (via API)
ansible windows -m win_shell -a "(Invoke-WebRequest -Uri 'http://localhost:19999/api/v1/info' -UseBasicParsing).Content | ConvertFrom-Json | Select-Object version, uid" --one-line
```

### Check Service Status
```bash
# All services at once
ansible netdata_nodes -m shell -a "systemctl is-active netdata 2>/dev/null || (Get-Service netdata).Status" --one-line
```

## Files and Paths Reference

### Linux (motoko, atom)
- Config: `/etc/netdata/netdata.conf`
- Cloud config: `/var/lib/netdata/cloud.d/cloud.conf`
- Logs: `/var/log/netdata/`
- Binary: `/usr/sbin/netdata`
- CLI: `/usr/bin/netdatacli`

### Windows (wintermute, armitage)
- Config: `C:\Program Files\Netdata\etc\netdata\netdata.conf`
- Cloud config: `C:\Program Files\Netdata\var\lib\netdata\cloud.d\cloud.conf`
- Logs: `C:\Program Files\Netdata\var\log\netdata\`
  - `service.log` - Service lifecycle events
  - `aclk.log` - ACLK connection logs (may be minimal)
- Binary: `C:\Program Files\Netdata\usr\bin\netdata.exe`
- CLI: `C:\Program Files\Netdata\usr\bin\netdatacli.exe`

## Next Steps

1. ✅ **COMPLETE** - All hosts verified online in Netdata Cloud dashboard
2. 📋 **TODO** - Monitor wintermute service stability over next 48-72 hours
3. 📋 **TODO** - Set up service monitoring alert if Netdata stops unexpectedly

## Additional Notes

- Both Windows hosts are running Netdata v2.8.1
- Both hosts are running Windows 11 Build 26200
- Claim tokens are shared (same room: cb3e9378-1d0e-4016-8cbd-5283c3f87119)
- MQTT version 5 is in use on all hosts
- No proxy configuration needed (direct connection)

