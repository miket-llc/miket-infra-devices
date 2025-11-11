# Tailscale SSH Setup - Complete Guide

**Goal:** SSH from any machine to any machine on the tailnet for remote administration

**Current Tailnet:** pangolin-vega.ts.net  
**Working:** motoko (SSH enabled)  
**Needs Setup:** armitage, wintermute, count-zero

---

## Quick Test (What Works Now)

```bash
# From count-zero (or any device) to motoko:
tailscale ssh root@motoko
# ✅ This works!

tailscale ssh mdt@motoko
# ✅ This also works!
```

---

## Enable SSH on Each Device

### On motoko (Linux) - Already Done ✅
```bash
# Already working - no action needed
```

### On count-zero (macOS) - Your Current Machine
```bash
# Enable Tailscale SSH
sudo tailscale up --ssh

# Verify
tailscale status
# Should show: SSH enabled
```

### On armitage (Windows) - ⚠️ LIMITATION
**Tailscale SSH server is NOT supported on Windows.**

Windows can be a **client** (connect to Linux/macOS via Tailscale SSH) but **cannot accept incoming Tailscale SSH connections**.

**Solution:** Use **OpenSSH Server** with regular SSH over Tailscale IPs:

```powershell
# In PowerShell as Administrator:

# 1. Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server

# 2. Start SSH service
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# 3. Verify Tailscale IP
tailscale status
# Note the IP address (e.g., 100.72.64.90)

# 4. Configure firewall (if needed)
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

**Then connect from other devices:**
```bash
# From count-zero or motoko:
ssh Administrator@100.72.64.90  # Use Tailscale IP
# Or if you set up a hostname:
ssh Administrator@armitage.pangolin-vega.ts.net
```

### On wintermute (Windows) - Currently Offline
Same as armitage (install OpenSSH Server, not Tailscale SSH server).

---

## Testing SSH Access

### From count-zero to motoko
```bash
tailscale ssh root@motoko
# Should work immediately

tailscale ssh mdt@motoko
# Should work immediately
```

### From count-zero to armitage (after setup)
```bash
# Windows doesn't support Tailscale SSH server - use regular SSH with Tailscale IP
ssh Administrator@100.72.64.90
# Or if hostname resolves:
ssh Administrator@armitage.pangolin-vega.ts.net
```

### From count-zero to wintermute (after online)
```bash
# Same as armitage - use regular SSH with Tailscale IP
ssh Administrator@100.89.63.123
# Or if hostname resolves:
ssh Administrator@wintermute.pangolin-vega.ts.net
```

### From motoko to count-zero (after setup)
```bash
# SSH from motoko back to count-zero:
tailscale ssh miket@count-zero
# Replace "miket" with your actual macOS username
```

---

## Current Device Status

| Device | IP | OS | SSH Status | Tags | Action Needed |
|--------|----|----|------------|------|---------------|
| **motoko** | 100.92.23.71 | Linux | ✅ Tailscale SSH | tag:server | None |
| **count-zero** | 100.111.7.19 | macOS | ⏳ Unknown | None | Run `sudo tailscale up --ssh` |
| **armitage** | 100.72.64.90 | Windows | ❌ Not configured | None | Install OpenSSH Server (Tailscale SSH not supported on Windows) |
| **wintermute** | 100.89.63.123 | Windows | ❌ Offline | None | Bring online, install OpenSSH Server |
| **iOS devices** | Various | iOS | N/A | None | No SSH needed |

**Note:** Windows machines can **connect** via Tailscale SSH but cannot **accept** Tailscale SSH connections. Use OpenSSH Server instead.

---

## For n8n Workflows & Ollama Access

**n8n will run on motoko** and needs to reach other devices:

### Service-to-Service Communication (No SSH Keys Needed!)

**For ollama on Windows devices:**
1. **Tag wintermute and armitage as `tag:server`** (see `TAG_WINDOWS_DEVICES_FOR_OLLAMA.md`)
2. ACL rule already allows `tag:server` → `tag:server:*` (any port)
3. n8n can reach ollama via HTTP API directly:

```javascript
// n8n HTTP Request node - no SSH needed!
URL: http://100.89.63.123:11434/api/generate
Method: POST
Body: { "model": "llama2", "prompt": "..." }
```

**No SSH keys needed** - Tailscale network ACL handles authentication via Entra ID.

### Command Execution (Requires SSH Setup)

Only if you need to **run commands** (not just HTTP API calls):

```bash
# Linux/macOS devices (use Tailscale SSH):
tailscale ssh root@motoko "command here"  # ✅ Works
```

# Windows devices (must use regular SSH - Tailscale SSH not supported):
ssh Administrator@100.72.64.90 "command"  # armitage
ssh Administrator@100.89.63.123 "command" # wintermute

# Note: You'll need SSH keys configured for passwordless access
```

**After setup:**
- ✅ Ollama HTTP API: Works via network ACL (just tag devices)
- ✅ Service access: HTTP/HTTPS on any port (via ACL)
- ⏳ Command execution: Needs SSH keys (only if needed)

---

## Quick Setup Checklist

On each machine, run:

**motoko:** ✅ Already done

**count-zero (macOS):**
```bash
sudo tailscale up --ssh
```

**armitage (Windows):**
```powershell
# As Administrator
# NOTE: Tailscale SSH server not supported on Windows - use OpenSSH instead
Add-WindowsCapability -Online -Name OpenSSH.Server
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Verify Tailscale IP
tailscale status

# Connect from other devices using Tailscale IP:
# ssh Administrator@<armitage-tailscale-ip>
```

**wintermute (Windows):**
```powershell
# Same as armitage after bringing machine online
```

**Test:**
```bash
# From count-zero, try each:
tailscale ssh root@motoko        # ✅ Works now
tailscale ssh Administrator@armitage  # After setup
tailscale ssh Administrator@wintermute  # After online + setup
```

---

## Verification

After setup, verify from count-zero:

```bash
# Test all connections
for device in motoko armitage wintermute; do
  echo "Testing $device..."
  tailscale ssh root@$device "hostname" && echo "✅" || echo "❌"
done
```

**Expected:** All show ✅

---

**Current Status:** motoko SSH working, other devices need `tailscale up --ssh` enabled on each machine.

