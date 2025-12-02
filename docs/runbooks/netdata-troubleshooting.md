# Netdata Troubleshooting Quick Reference

## Quick Status Check

### Check All Netdata Services
```bash
cd /home/mdt/dev/miket-infra-devices/ansible

# All hosts at once
ansible netdata_nodes -m shell -a "systemctl is-active netdata 2>/dev/null || powershell -c '(Get-Service netdata).Status'" --one-line
```

### Check ACLK Cloud Connection

**Linux (motoko, atom):**
```bash
ansible linux -m shell -a "netdatacli aclk-state | grep -E 'ACLK Available|Online|Claimed'" --one-line
```

**Windows (wintermute, armitage):**

Option 1 - Via API (fastest, most reliable):
```bash
ansible windows -m win_shell -a "(Invoke-WebRequest -Uri 'http://localhost:19999/api/v1/info' -UseBasicParsing).Content | ConvertFrom-Json | Select-Object version, uid" --one-line
```

Option 2 - Via netdatacli (use PowerShell job with timeout):
```bash
ansible windows -m win_shell -a "\$job = Start-Job -ScriptBlock { & 'C:\Program Files\Netdata\usr\bin\netdatacli.exe' aclk-state 2>&1 }; Wait-Job \$job -Timeout 10 | Out-Null; if (\$job.State -eq 'Completed') { Receive-Job \$job | Select-String -Pattern 'Online|Claimed' } else { 'TIMEOUT' }; Remove-Job \$job -Force"
```

## Common Issues

### Issue: Windows host shows offline in Netdata Cloud

**Symptoms:**
- Host appears offline in Netdata Cloud dashboard
- `netdatacli aclk-state` hangs or times out

**Troubleshooting Steps:**

1. **Check service is running:**
   ```bash
   ansible <hostname> -m win_shell -a "Get-Service netdata | Select-Object Status, Name, DisplayName"
   ```

2. **Restart service if stopped:**
   ```bash
   ansible <hostname> -m win_shell -a "Restart-Service netdata -Force; Start-Sleep -Seconds 10; Get-Service netdata"
   ```

3. **Verify claim files exist:**
   ```bash
   ansible <hostname> -m win_shell -a "Get-ChildItem 'C:\Program Files\Netdata\var\lib\netdata\cloud.d' | Select-Object Name, Length, LastWriteTime"
   ```
   
   Expected files:
   - `claimed_id` (~36 bytes)
   - `cloud.conf` (~395 bytes)
   - `private.pem` (~1700 bytes)
   - `public.pem` (~451 bytes)

4. **Check network connectivity:**
   ```bash
   ansible <hostname> -m win_shell -a "Test-NetConnection -ComputerName app.netdata.cloud -Port 443 | Select-Object ComputerName, RemoteAddress, TcpTestSucceeded"
   ```

5. **Check Windows Firewall:**
   ```bash
   ansible <hostname> -m win_shell -a "Get-NetFirewallProfile | Select-Object Name, Enabled"
   ```

6. **Check ACLK status via API:**
   ```bash
   ansible <hostname> -m win_shell -a "(Invoke-WebRequest -Uri 'http://localhost:19999/api/v1/info' -UseBasicParsing).Content | ConvertFrom-Json | Select-Object -ExpandProperty host_labels | Select-Object _aclk_available, _hostname"
   ```

### Issue: Claim files missing

**Solution:** Re-claim the agent to Netdata Cloud

1. Get claim token from Netdata Cloud UI (https://app.netdata.cloud)
2. Run claim command on Windows:
   ```powershell
   & "C:\Program Files\Netdata\usr\bin\netdata" -W "claim -token=<TOKEN> -rooms=<ROOM_ID> -url=https://app.netdata.cloud"
   ```

### Issue: Service keeps stopping

**Diagnosis:**
```bash
# Check Windows Event Viewer
ansible <hostname> -m win_shell -a "Get-WinEvent -FilterHashtable @{LogName='System'} -MaxEvents 100 | Where-Object { \$_.Message -match 'netdata' } | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List"
```

**Common Causes:**
- Windows Update restarted the system
- Service crashed (check Application event log)
- Manual stop
- Resource constraints (memory, CPU)

## File Paths Reference

### Linux (motoko, atom)
- **Config:** `/etc/netdata/netdata.conf`
- **Cloud config:** `/var/lib/netdata/cloud.d/cloud.conf`
- **Logs:** `/var/log/netdata/`
- **Binary:** `/usr/sbin/netdata`
- **CLI:** `/usr/bin/netdatacli`

### Windows (wintermute, armitage)
- **Config:** `C:\Program Files\Netdata\etc\netdata\netdata.conf`
- **Cloud config:** `C:\Program Files\Netdata\var\lib\netdata\cloud.d\cloud.conf`
- **Logs:** `C:\Program Files\Netdata\var\log\netdata\`
  - `service.log` - Service lifecycle events
  - `aclk.log` - ACLK connection logs
- **Binary:** `C:\Program Files\Netdata\usr\bin\netdata.exe`
- **CLI:** `C:\Program Files\Netdata\usr\bin\netdatacli.exe`

## Useful API Endpoints

### Local Netdata API (port 19999)

**System Info:**
```
http://localhost:19999/api/v1/info
```

**Node Instances (includes ACLK status):**
```
http://localhost:19999/api/v2/node_instances
```

**Alarms:**
```
http://localhost:19999/api/v1/alarms
```

**All Charts:**
```
http://localhost:19999/api/v1/charts
```

## Known Issues

### netdatacli hangs on Windows when called via Ansible

**Issue:** Direct invocation of `netdatacli.exe aclk-state` hangs indefinitely when called through Ansible WinRM.

**Workaround 1 - Use PowerShell Jobs:**
```powershell
$job = Start-Job -ScriptBlock { & 'C:\Program Files\Netdata\usr\bin\netdatacli.exe' aclk-state 2>&1 }
Wait-Job $job -Timeout 10 | Out-Null
if ($job.State -eq 'Completed') { Receive-Job $job } else { 'TIMEOUT' }
Remove-Job $job -Force
```

**Workaround 2 - Use HTTP API:**
```powershell
(Invoke-WebRequest -Uri 'http://localhost:19999/api/v1/info' -UseBasicParsing).Content | ConvertFrom-Json
```

## Monitoring Setup

### Service Monitoring Alert

**TODO:** Set up automated alert if Netdata service stops on any host

Possible solutions:
1. Netdata monitoring itself (meta-monitoring)
2. Azure Monitor or similar
3. Cron job that checks service status and sends alert

## Related Documentation

- [Netdata Cloud Connectivity Incident - 2025-12-02](../troubleshooting/2025-12-02-netdata-cloud-connectivity.md)
- [Device Health Check Runbook](./device-health-check.md)
- [Netdata Official Docs](https://learn.netdata.cloud/)

## Emergency Contacts

- Netdata Cloud: https://app.netdata.cloud
- Community Forum: https://community.netdata.cloud
- GitHub Issues: https://github.com/netdata/netdata/issues

