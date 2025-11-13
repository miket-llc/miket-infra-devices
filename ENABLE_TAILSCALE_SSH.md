# CORRECTED: Windows Does Not Support Tailscale SSH Server

## Status: ARCHITECTURE CORRECTED

**CRITICAL FINDING:** Tailscale SSH server is NOT supported on native Windows.

The original assessment was incorrect. Windows devices (wintermute, armitage) cannot run Tailscale SSH server. 

## Actual Architecture

### Windows Devices (wintermute, armitage)
- ✅ **RDP Access:** Use native Windows RDP via `mstsc /v:wintermute.pangolin-vega.ts.net`
- ✅ **Ansible Management:** Use WinRM (already configured in inventory)
- ❌ **Tailscale SSH:** Not supported on native Windows
- ✅ **WSL2 SSH (Optional):** Could configure SSH server in WSL2 if direct SSH needed

### Linux/macOS Devices (motoko, count-zero)
- ✅ **Tailscale SSH:** Supported - verify with `tailscale status`

## Corrected Access Methods

### Windows Devices

**RDP (Remote Desktop):**
```powershell
# From any Windows device:
mstsc /v:wintermute.pangolin-vega.ts.net
mstsc /v:armitage.pangolin-vega.ts.net

# From Linux:
remmina -c rdp://wintermute.pangolin-vega.ts.net:3389

# From macOS:
open rdp://full%20address=s:wintermute.pangolin-vega.ts.net:3389
```

**Ansible (WinRM):**
```bash
# From motoko:
ansible wintermute -m win_ping
ansible armitage -m win_ping
```

### If Direct SSH to Windows is Required

Use WSL2 SSH server (requires additional setup):
1. Install OpenSSH server in WSL2
2. Install Tailscale in WSL2
3. SSH to WSL2 IP address (not Windows hostname)

**Not recommended** - Use RDP for interactive access, WinRM for automation.

## Verification

1. **Test RDP:** Should work immediately via Tailscale
2. **Test WinRM:** Requires vault password configuration
3. **Check Tailscale status:** Run `tailscale status` on each device

## Reference

See: docs/runbooks/TAILSCALE_DEVICE_SETUP.md for complete procedure (updated)

