# Wintermute Connectivity Troubleshooting Guide

## Quick Status Check

Run the automated troubleshooting script:
```bash
cd ~/miket-infra-devices
./scripts/troubleshoot-wintermute.sh
```

## Current Connectivity Status

Based on the latest diagnostic run:

✅ **DNS Resolution**: Working  
✅ **Tailscale Status**: Active and connected (direct connection)  
✅ **Ping Connectivity**: Working  
✅ **NoMachine Port (4000)**: Accessible  
✅ **WinRM Port (5985)**: Accessible  
⚠️ **Ansible Authentication**: Requires vault password (expected)

## Connectivity Tests

### 1. Basic Connectivity Tests

```bash
# Test DNS resolution
host wintermute.pangolin-vega.ts.net

# Test ping
ping -c 3 wintermute.pangolin-vega.ts.net

# Check Tailscale status
tailscale status | grep wintermute

# Test Tailscale ping
tailscale ping wintermute
```

### 2. Port Connectivity Tests

```bash
# Test NoMachine port (4000)
nc -zv wintermute.pangolin-vega.ts.net 4000

# Test WinRM port (5985)
nc -zv wintermute.pangolin-vega.ts.net 5985
```

### 3. Ansible Connectivity Test

```bash
# Test with vault password
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  playbooks/smoke-windows-remote-access.yml \
  --limit wintermute \
  --ask-vault-pass
```

## Common Issues and Solutions

### Issue: Device Shows as Offline in Tailscale

**Symptoms:**
- `tailscale status` shows wintermute as "offline"
- Ping fails
- All connectivity tests fail

**Solution:**
1. **On wintermute**, check Tailscale service:
   ```powershell
   Get-Service Tailscale
   Get-Process tailscale -ErrorAction SilentlyContinue
   ```

2. **Restart Tailscale** if needed:
   ```powershell
   Restart-Service Tailscale
   ```

3. **Verify Tailscale adapter**:
   ```powershell
   Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Tailscale*" }
   ```

### Issue: NoMachine Connection Fails

**Symptoms:**
- Port 4000 test fails
- Cannot connect via NoMachine client

**Solution:**
1. **Check NoMachine service on wintermute**:
   ```powershell
   Get-Service nxservice
   ```

2. **Check Windows Firewall**:
   ```powershell
   Get-NetFirewallRule -Name "*NoMachine*" | Select-Object DisplayName, Enabled, Direction
   ```

3. **Verify NoMachine is listening on port 4000**:
   ```powershell
   Get-NetTCPConnection -LocalPort 4000 | Select-Object LocalAddress, State
   ```

4. **Check Tailscale ACL rules** in miket-infra (should allow port 4000)

### Issue: WinRM/Ansible Connection Fails

**Symptoms:**
- Port 5985 test passes but Ansible fails
- Error: "ntlm: auth method ntlm requires a password"

**Solution:**
1. **This is expected** - Ansible requires vault password:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     playbooks/smoke-windows-remote-access.yml \
     --limit wintermute \
     --ask-vault-pass
   ```

2. **Check WinRM service on wintermute**:
   ```powershell
   Get-Service WinRM
   ```

3. **Verify WinRM is configured**:
   ```powershell
   winrm get winrm/config
   ```

### Issue: DNS Resolution Fails

**Symptoms:**
- Cannot resolve `wintermute.pangolin-vega.ts.net`
- Host command fails

**Solution:**
1. **Check Tailscale MagicDNS**:
   ```bash
   tailscale status
   ```

2. **Verify DNS settings** on control node (motoko):
   ```bash
   cat /etc/resolv.conf
   ```

3. **Test direct IP connection**:
   ```bash
   # Get IP from tailscale status
   tailscale status | grep wintermute
   # Then ping the IP directly
   ping 100.89.63.123  # Replace with actual IP
   ```

## Network Configuration

### Tailscale Configuration

- **Hostname**: `wintermute`
- **FQDN**: `wintermute.pangolin-vega.ts.net`
- **Tailscale IP**: `100.89.63.123` (may vary)
- **Tags**: `tag:workstation`, `tag:windows`, `tag:gpu_12gb`

### Port Configuration

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| NoMachine | 4000 | TCP | Tailscale only |
| WinRM | 5985 | TCP | Tailscale only |
| RDP | 3389 | TCP | Disabled (architectural compliance) |

## Verification Checklist

- [ ] DNS resolves correctly
- [ ] Tailscale shows device as "active"
- [ ] Ping works
- [ ] NoMachine port 4000 is accessible
- [ ] WinRM port 5985 is accessible
- [ ] Ansible can connect (with vault password)

## Related Documentation

- [Armitage Connectivity Troubleshooting](./armitage-connectivity-troubleshooting.md) - Similar process for armitage
- [NoMachine Client Testing](./runbooks/nomachine-client-testing.md) - End-to-end NoMachine testing
- [Ansible Windows Setup](./ansible-windows-setup.md) - WinRM configuration guide

## Automated Troubleshooting

For comprehensive diagnostics, use the troubleshooting script:

```bash
cd ~/miket-infra-devices
./scripts/troubleshoot-wintermute.sh
```

This script tests all connectivity aspects and provides detailed diagnostics.

