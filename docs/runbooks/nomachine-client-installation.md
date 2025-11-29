---
document_title: "NoMachine Client Installation and Standardization"
author: "Codex-UX-010 (UX/DX Designer)"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-nomachine-standardization
---

# NoMachine Client Installation and Standardization

**Purpose:** Standardized procedure for installing and configuring NoMachine clients across all devices (macOS, Windows, Linux)

**Scope:** All workstations requiring remote desktop access to NoMachine servers

**Architecture:** NoMachine is the sole remote desktop solution (RDP/VNC architecturally retired 2025-11-22)

---

## Overview

NoMachine clients are deployed via Ansible playbooks that:
1. Install the NoMachine client application
2. Create standardized connection profiles (port 4000, Tailscale hostnames)
3. Configure helper scripts for quick connections

**Standardized Configuration:**
- **Port:** 4000 (all servers)
- **Hostnames:** `{hostname}.pangolin-vega.ts.net` (Tailscale MagicDNS)
- **Protocol:** NX (NoMachine protocol)
- **Transport:** Tailscale network only (100.64.0.0/10)

---

## Automated Installation (Recommended)

### Deploy to All Devices

```bash
cd /path/to/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml
```

### Deploy to Specific Platform

```bash
# macOS only
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --limit macos

# Windows only
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --limit windows

# Linux only
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --limit linux
```

### Deploy to Single Device

```bash
# Example: count-zero (macOS)
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --limit count-zero

# Example: wintermute (Windows)
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --limit wintermute
```

---

## Manual Installation (Fallback)

### macOS Installation

**1. Download NoMachine Client**

```bash
# Visit: https://www.nomachine.com/download
# Or download directly:
cd ~/Downloads
curl -O https://download.nomachine.com/download/9.2/MacOSX/nomachine_9.2.18_3.dmg
```

**2. Install**

```bash
# Open DMG
open nomachine_9.2.18_3.dmg

# Drag NoMachine.app to Applications folder
# Or run installer if provided

# Verify installation
ls -la /Applications/NoMachine.app
```

**3. Create Connection Profiles**

Connection profiles are stored in `~/Documents/NoMachine/` as `.nxs` files.

**Pre-configured servers:**
- `motoko.nxs` - Linux server (Fedora)
- `wintermute.nxs` - Windows server
- `armitage.nxs` - Windows server

**Manual profile creation:**
1. Launch `/Applications/NoMachine.app`
2. Click "New" or "Add connection"
3. Enter connection details:
   - **Protocol:** NX
   - **Host:** `{hostname}.pangolin-vega.ts.net`
   - **Port:** `4000`
   - **Authentication:** Password
   - **Username:** `mdt`
4. Save connection

**4. Create Helper Script (Optional)**

```bash
sudo tee /usr/local/bin/nomachine << 'EOF'
#!/bin/bash
# NoMachine connection helper
HOST="${1:-motoko}"
open "nx://${HOST}.pangolin-vega.ts.net:4000"
EOF

sudo chmod +x /usr/local/bin/nomachine
```

**Usage:**
```bash
nomachine motoko      # Connect to motoko
nomachine wintermute  # Connect to wintermute
nomachine armitage    # Connect to armitage
```

---

### Windows Installation

**1. Install via Chocolatey (Recommended)**

```powershell
# Install Chocolatey if not present
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install NoMachine
choco install nomachine -y
```

**2. Install Manually**

1. Download from: https://www.nomachine.com/download
2. Run installer: `nomachine.exe`
3. Follow installation wizard

**3. Create Connection Profiles**

Profiles are stored in `%USERPROFILE%\Documents\NoMachine\` as `.nxs` files.

**Pre-configured servers:**
- `motoko.nxs`
- `wintermute.nxs`
- `armitage.nxs`

**Manual profile creation:**
1. Launch NoMachine from Start Menu
2. Click "New" or "Add connection"
3. Enter connection details (same as macOS)
4. Save connection

**4. Create Helper Script (Optional)**

```powershell
# Create nomachine.ps1 in System32
@"
param([string]`$Hostname = "motoko")
`$Target = "`${Hostname}.pangolin-vega.ts.net:4000"
& "C:\Program Files\NoMachine\bin\nxplayer.exe" --session `$Target
"@ | Out-File -FilePath C:\Windows\System32\nomachine.ps1 -Encoding UTF8
```

**Usage:**
```powershell
nomachine motoko
nomachine wintermute
nomachine armitage
```

---

### Linux Installation

**1. Download and Install**

```bash
# Download installer
cd /tmp
curl -O https://download.nomachine.com/download/8.x/Linux/nomachine_8.15.3_4_x86_64.run
chmod +x nomachine_8.15.3_4_x86_64.run

# Install
sudo ./nomachine_8.15.3_4_x86_64.run install

# Verify installation
ls -la /usr/NX/bin/nxplayer
```

**2. Create Connection Profiles**

Profiles are stored in `~/Documents/NoMachine/` as `.nxs` files.

**Pre-configured servers:**
- `motoko.nxs`
- `wintermute.nxs`
- `armitage.nxs`

**Manual profile creation:**
1. Launch NoMachine from Applications menu or run `nxplayer`
2. Click "New" or "Add connection"
3. Enter connection details (same as macOS/Windows)
4. Save connection

**3. Create Helper Script (Optional)**

```bash
sudo tee /usr/local/bin/nomachine << 'EOF'
#!/bin/bash
# NoMachine connection helper - uses Tailscale MagicDNS
HOST="${1:-motoko}"
TARGET="${HOST}.pangolin-vega.ts.net:4000"
if [ -f /usr/NX/bin/nxplayer ]; then
  /usr/NX/bin/nxplayer --session "${TARGET}"
else
  echo "NoMachine client not found. Install NoMachine to use this script."
  exit 1
fi
EOF

sudo chmod +x /usr/local/bin/nomachine
```

**Usage:**
```bash
nomachine motoko
nomachine wintermute
nomachine armitage
```

---

## Connection Profile Standardization

### Standard Profile Template

All connection profiles use these standardized settings:

```xml
<!DOCTYPE NXClientSettings>
<NXClientSettings application="nxclient" version="2.0">
  <group name="General" >
    <option key="Server host" value="{hostname}.pangolin-vega.ts.net" />
    <option key="Server port" value="4000" />
    <option key="Session" value="{unix|windows}" />
    <option key="Resolution" value="fit" />
    <option key="Link quality" value="9" />
  </group>
  <group name="Advanced" >
    <option key="Grab the keyboard input" value="true" />
    <option key="Grab the mouse input" value="true" />
  </group>
</NXClientSettings>
```

### Available Servers

| Server | Hostname | Port | OS | Session Type |
|--------|----------|------|----|--------------| 
| motoko | motoko.pangolin-vega.ts.net | 4000 | Linux (Fedora) | unix |
| wintermute | wintermute.pangolin-vega.ts.net | 4000 | Windows | windows |
| armitage | armitage.pangolin-vega.ts.net | 4000 | Windows | windows |

---

## Verification

### Verify Client Installation

**macOS:**
```bash
test -d /Applications/NoMachine.app && echo "PASS" || echo "FAIL"
/Applications/NoMachine.app/Contents/Frameworks/bin/nxplayer --version
```

**Windows:**
```powershell
Test-Path "C:\Program Files\NoMachine\bin\nxplayer.exe"
& "C:\Program Files\NoMachine\bin\nxplayer.exe" --version
```

**Linux:**
```bash
test -f /usr/NX/bin/nxplayer && echo "PASS" || echo "FAIL"
/usr/NX/bin/nxplayer --version
```

### Verify Connection Profiles

**macOS/Linux:**
```bash
ls -la ~/Documents/NoMachine/*.nxs
# Expected: motoko.nxs, wintermute.nxs, armitage.nxs
```

**Windows:**
```powershell
Get-ChildItem "$env:USERPROFILE\Documents\NoMachine\*.nxs"
# Expected: motoko.nxs, wintermute.nxs, armitage.nxs
```

### Test Connection

**From any platform:**
```bash
# Test connectivity to server
nc -zv motoko.pangolin-vega.ts.net 4000
# Expected: Connection to motoko.pangolin-vega.ts.net port 4000 [tcp/*] succeeded!

# Launch NoMachine and attempt connection
# macOS: open /Applications/NoMachine.app
# Windows: Start Menu > NoMachine
# Linux: nxplayer
```

---

## Troubleshooting

### Client Not Found

**Symptoms:** Helper script fails with "NoMachine client not found"

**Resolution:**
1. Verify installation: Check paths above
2. Reinstall if missing: Follow manual installation steps
3. Check PATH: Ensure NoMachine binaries are in system PATH

### Connection Refused

**Symptoms:** "Connection refused" when connecting

**Diagnosis:**
```bash
# Test port connectivity
nc -zv {hostname}.pangolin-vega.ts.net 4000

# Check Tailscale connectivity
ping {hostname}.pangolin-vega.ts.net
```

**Resolution:**
1. Verify Tailscale is connected
2. Verify server NoMachine service is running
3. Check firewall rules allow port 4000

### MagicDNS Not Resolving

**Symptoms:** "Could not resolve hostname"

**Resolution:**
1. Use IP addresses instead (workaround)
2. Get IPs: `tailscale status | grep {hostname}`
3. Create IP-based connection profile
4. Escalate MagicDNS fix to miket-infra

---

## Time to First Connection (TTFC)

**Target:** < 2 minutes for new device

**Measurement:**
1. Start timer when beginning installation
2. Stop timer when first successful connection established
3. Document in test results

**Components:**
- Download time: ~30 seconds
- Installation time: ~30 seconds
- Profile creation: ~30 seconds
- First connection: ~10 seconds
- **Total:** ~100 seconds (< 2 minutes target)

---

## Cloudflare Access Integration

**Wave 2 Enhancement:** NoMachine access may be protected by Cloudflare Access policies.

**Certificate Enrollment Required:**
- All devices accessing Cloudflare Access-protected applications must enroll with Cloudflare WARP
- See: [Certificate Enrollment Automation](../../ansible/roles/certificate_enrollment/README.md)

**Access Policy:**
- Device personas (workstation, server) mapped to Cloudflare Access groups
- See: [Cloudflare Access Mapping](./cloudflare-access-mapping.md)

**Validation:**
```bash
# Validate Cloudflare Access configuration
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-cloudflare-access.yml
```

## Related Documentation

- [NoMachine Client Testing](./nomachine-client-testing.md)
- [NoMachine Server Deployment](../../miket-infra/docs/communications/COMMUNICATION_LOG.md#2025-11-22-nomachine-second-pass) (miket-infra)
- [Device Onboarding Runbook](./onboarding.md)
- [Cloudflare Access Mapping](./cloudflare-access-mapping.md)
- [Certificate Enrollment Automation](../../ansible/roles/certificate_enrollment/README.md)

---

**End of Installation Procedure**

