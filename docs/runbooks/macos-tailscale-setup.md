# macOS Tailscale Setup - Best Practices

## Overview

macOS devices require special configuration for Tailscale MagicDNS when installed via Homebrew. This runbook covers best practices for onboarding macOS devices to the Tailnet with proper DNS resolution, SSH access, and remote management capabilities.

## Architecture: Bootstrap vs Ansible

### Bootstrap (Manual, Run Once on Device)

**What:** Initial device setup that requires local access
**When:** First time configuring a macOS device
**How:** Run `bootstrap-macos.sh` locally on the device
**Why:** Requires sudo and interactive authentication (Tailscale login URL)

### Ansible (Automated, Run from Control Node)

**What:** Configuration management and drift detection
**When:** After bootstrap, for ongoing management
**How:** Run `setup-macos-tailscale.yml` from motoko
**Why:** Ensures /etc/resolver stays configured, validates Tailscale status

## Best Practices

### 1. Two-Stage Setup (Bootstrap + Ansible)

**Stage 1: Bootstrap (Device-Local)**
```bash
# On the macOS device (requires user present for Tailscale auth)
curl -fsSL https://raw.githubusercontent.com/miket-llc/miket-infra-devices/main/scripts/bootstrap-macos.sh | bash
```

This handles:
- ✅ Homebrew and Tailscale installation
- ✅ Tailscale authentication (interactive - requires user click)
- ✅ --accept-dns flag (enables MagicDNS)
- ✅ /etc/resolver configuration (CRITICAL for Homebrew Tailscale)
- ✅ SSH enablement
- ✅ Initial verification

**Stage 2: Ansible (From Control Node)**
```bash
# From motoko after bootstrap
cd /home/mdt/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-macos-tailscale.yml -l count-zero
```

This handles:
- ✅ Verifies Tailscale running
- ✅ Ensures /etc/resolver file exists (idempotent)
- ✅ Validates MagicDNS resolution
- ✅ Drift detection and remediation

### 2. Why /etc/resolver is Required (Homebrew Limitation)

**Problem:** Homebrew Tailscale doesn't automatically configure macOS DNS resolvers like the GUI app does.

**Solution:** Manual /etc/resolver file creation pointing `*.tailnet-domain.ts.net` queries to Tailscale DNS (100.100.100.100).

**Cannot Be Avoided:** This is a Homebrew vs macOS App limitation, not our fault.

### 3. Credentials Required

**Bootstrap Phase:**
- **Tailscale Authentication:** User must click auth URL (opens browser)
- **sudo Password:** Required for system configuration
- **User Present:** Must be at keyboard for interactive auth

**Ansible Phase (After Bootstrap):**
- **SSH Access:** Passwordless via Tailscale SSH or key-based auth
- **sudo Password:** Stored in Ansible Vault (`vault_count_zero_sudo_password`)
- **No User Required:** Fully automated

### 4. Separation of Concerns

**miket-infra Repository:**
- Tailscale ACL policies (network layer)
- MagicDNS enablement (Terraform)
- Device tags definitions

**miket-infra-devices Repository (THIS REPO):**
- Device enrollment scripts (bootstrap-macos.sh)
- DNS resolver configuration (/etc/resolver)
- Ansible automation for configuration management
- Remote management setup (SSH, VNC)

## Complete Setup Process

### New macOS Device Onboarding

**Step 1: Run Bootstrap Locally**
```bash
# On the macOS device
curl -fsSL https://raw.githubusercontent.com/miket-llc/miket-infra-devices/main/scripts/bootstrap-macos.sh | bash

# Or clone repo first:
git clone https://github.com/miket-llc/miket-infra-devices.git
cd miket-infra-devices
./scripts/bootstrap-macos.sh
```

**Step 2: Authenticate Tailscale**
- Script will print authentication URL
- Click URL, complete SSO login
- Wait for "Success" message

**Step 3: Verify Bootstrap**
```bash
# Test MagicDNS
ping motoko.pangolin-vega.ts.net

# Test Tailscale status
tailscale status

# Test SSH (if enabled)
ssh miket@motoko.pangolin-vega.ts.net hostname
```

**Step 4: Add to Ansible Inventory (if not present)**
```yaml
# ansible/inventory/hosts.yml
macos:
  hosts:
    device-name:
      ansible_host: device-name.pangolin-vega.ts.net
      ansible_user: miket  # Or appropriate username
      ansible_become: true
      ansible_become_method: sudo
      ansible_become_password: "{{ vault_device_sudo_password | default(omit) }}"
      ansible_python_interpreter: /usr/bin/python3
```

**Step 5: Run Ansible Configuration**
```bash
# From motoko
cd /home/mdt/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-macos-tailscale.yml -l device-name
```

**Step 6: Install Microsoft Remote Desktop (if needed)**
- Mac App Store: https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466
- Or: `brew install --cask microsoft-remote-desktop`
- **Configure Local Network Access:** System Settings → Privacy & Security → Local Network → Microsoft Remote Desktop → Enable

## What Can vs Cannot Be Automated

### ✅ CAN Be Automated via Ansible

- /etc/resolver file creation and management
- DNS cache flushing
- SSH enablement via systemsetup
- SSH key deployment
- Configuration validation
- Drift detection and remediation

### ❌ CANNOT Be Automated

**Initial Tailscale Authentication:**
- Requires interactive browser auth (SSO login)
- User must click "Approve" button
- Cannot be scripted (by design - security)

**Solution:** Bootstrap script handles this, prompts user, then continues automation.

**sudo Password Entry (First Time):**
- Bootstrap requires sudo for Tailscale service start
- Can be automated AFTER first setup (Ansible Vault)

**Microsoft Remote Desktop Installation:**
- Mac App Store requires Apple ID login (cannot be automated)
- Can use Homebrew cask as alternative: `brew install --cask microsoft-remote-desktop`

**Local Network Access Permission:**
- macOS Ventura+ requires manual permission grant in System Settings
- Cannot be automated via MDM without corporate enrollment
- User must click "Allow" in System Settings

## Microsoft Remote Desktop Configuration

### Error 0x104: "PC can't be found"

**Causes:**
1. MagicDNS not configured (hostname doesn't resolve)
2. Local Network Access not granted in macOS

**Solutions:**

**Fix 1: Use Tailscale IP Address**
- Instead of `wintermute.pangolin-vega.ts.net`
- Use Tailscale IP: `100.89.63.123` (wintermute) or `100.72.64.90` (armitage)
- Works immediately, bypasses DNS resolution

**Fix 2: Enable Local Network Access**
1. System Settings → Privacy & Security → Local Network
2. Find "Microsoft Remote Desktop"
3. Toggle ON
4. Restart Microsoft Remote Desktop app

**Fix 3: Enable MagicDNS**
```bash
sudo tailscale up --accept-dns --ssh
```

### Verification Commands

**From macOS:**
```bash
# Test DNS resolution
ping wintermute.pangolin-vega.ts.net
# Should resolve to 100.89.63.123

# Test port accessibility  
nc -zv wintermute.pangolin-vega.ts.net 3389
# Should show: Connection succeeded

# Test Tailscale status
tailscale status | grep wintermute
# Should show wintermute with its IP

# Check resolver file
cat /etc/resolver/pangolin-vega.ts.net
# Should contain: nameserver 100.100.100.100
```

## Troubleshooting

### MagicDNS Not Working After Bootstrap

**Check resolver file exists:**
```bash
ls -la /etc/resolver/
cat /etc/resolver/pangolin-vega.ts.net
```

**Recreate if missing:**
```bash
TAILNET=$(tailscale status --json | jq -r '.MagicDNSSuffix')
sudo mkdir -p /etc/resolver
sudo bash -c "echo 'nameserver 100.100.100.100' > /etc/resolver/$TAILNET"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Verify Tailscale was configured with --accept-dns:**
```bash
tailscale status --json | jq '.Self'
# Check if DNSName is set
```

**If not, reconfigure:**
```bash
sudo tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
```

### SSH Not Working

**Enable Remote Login:**
```bash
sudo systemsetup -setremotelogin on
sudo systemsetup -getremotelogin
```

**Test from another device:**
```bash
# Via Tailscale SSH
tailscale ssh miket@count-zero hostname

# Via regular SSH  
ssh miket@count-zero.pangolin-vega.ts.net hostname
```

## Maintenance and Drift Detection

**Regular Validation:**
```bash
# From motoko
ansible macos -i inventory/hosts.yml -m ping

# Full validation
ansible-playbook -i inventory/hosts.yml playbooks/setup-macos-tailscale.yml
```

**Common Drift Scenarios:**
1. /etc/resolver file deleted during OS update → Ansible recreates it
2. Remote Login disabled by user → Ansible re-enables it
3. Tailscale disconnected → Ansible detects and reports (requires manual reconnect)

## Security Considerations

**Defense in Depth:**
- macOS firewall restricts SSH to Tailscale subnet (if enabled)
- Tailscale ACL controls network-level access (miket-infra)
- SSH key authentication (no passwords)
- sudo requires password (stored in Ansible Vault)

**Least Privilege:**
- Regular user account (miket) with sudo
- No root login
- SSH key-based auth only

## Related Documentation

- [Bootstrap Script](../../scripts/bootstrap-macos.sh)
- [Ansible Role](../../ansible/roles/tailscale_macos/)
- [Count-Zero Setup](../../devices/count-zero/ENABLE_REMOTE_MANAGEMENT.md)
- [Tailnet Architecture](../architecture/tailnet.md)
- [IaC/CaC Principles](../architecture/iac-cac-principles.md)

