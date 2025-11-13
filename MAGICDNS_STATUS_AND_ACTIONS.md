# MagicDNS Status and Required Actions

## Current Status

### ✅ Hostname Resolution Working
- `ping armitage` resolves to `100.72.64.90` ✅
- `ping count-zero` resolves to `100.111.7.19` ✅ 
- Basic MagicDNS functionality is operational

### ⚠️ DNS Field Not Configured
All devices show `DNS: null` in Tailscale status, but hostname resolution still works.
This suggests MagicDNS is working but the `--accept-dns` flag needs to be explicitly set.

### Devices Status
1. **motoko** (100.92.23.71) - Connected, hostname resolution works
2. **armitage** (100.72.64.90) - Active, WinRM port 5985 open, needs DNS flag
3. **wintermute** (100.89.63.123) - Offline/unreachable
4. **count-zero** (100.111.7.19) - Active, SSH not available

## Required Actions

### Armitage (Windows) - READY TO FIX
WinRM is accessible. Run on armitage directly or use Python script:

**Option 1: Run directly on armitage (PowerShell as Admin):**
```powershell
tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming --accept-routes --accept-dns
```

**Option 2: From motoko with password:**
```bash
python3 /tmp/fix_armitage_dns.py
```

**Option 3: Use Ansible with vault:**
```bash
cd /home/mdt/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml --ask-vault-pass fix-magicdns-playbook.yml
```

### Wintermute (Windows) - OFFLINE
Device is currently offline. When it comes online:
```powershell
tailscale up --advertise-tags=tag:workstation,tag:windows,tag:gaming --accept-routes --accept-dns
```

### Count-Zero (macOS) - SSH NOT AVAILABLE
SSH is refused. Either:
1. Enable SSH on count-zero
2. Run locally on count-zero:
```bash
tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
```

### Motoko (Linux) - DO NOT TOUCH
Already working, SSH connection active from count-zero. DO NOT run tailscale commands here.

## Verification Commands

After fixing each device:

**Windows:**
```powershell
tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty Self | Select-Object DNS
Test-NetConnection -ComputerName motoko -InformationLevel Quiet
```

**Linux/macOS:**
```bash
tailscale status --json | jq '.Self.DNS'
ping -c 1 motoko
```

## RDP/VNC Verification (TODO)

After DNS is fixed, verify remote desktop access:

**RDP to Windows:**
```bash
# From motoko
xfreerdp /v:armitage.pangolin-vega.ts.net /u:mdt
xfreerdp /v:wintermute.pangolin-vega.ts.net /u:mdt
```

**VNC (if configured):**
```bash
# Check VNC ports
nc -zv armitage.pangolin-vega.ts.net 5900
nc -zv wintermute.pangolin-vega.ts.net 5900
```

## Files Created
- `devices/armitage/scripts/Fix-MagicDNS-Now.ps1`
- `devices/wintermute/scripts/Fix-MagicDNS-Now.ps1`
- `devices/count-zero/fix-magicdns-now.sh`
- `/tmp/fix_armitage_dns.py` (requires password)

## Next Steps
1. Fix armitage (WinRM accessible, needs password or direct access)
2. Wait for wintermute to come online, then fix
3. Fix count-zero (needs SSH enabled or local access)
4. Verify RDP/VNC connectivity


