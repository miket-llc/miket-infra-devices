# 🚨 CRITICAL FIX: MagicDNS Broken - Root Cause & Remediation

**Date:** 2025-01-XX  
**Severity:** CRITICAL - Blocks SSH and RDP connectivity  
**Status:** ✅ FIXED - Scripts updated, remediation required for existing devices

---

## 🔍 Root Cause Analysis

### The Problem
MagicDNS was enabled in Terraform (`miket-infra/infra/tailscale/entra-prod/main.tf`), but **all devices were enrolled without the `--accept-dns` flag**. This means:

- ❌ Devices cannot resolve hostnames (e.g., `ping motoko` fails)
- ❌ SSH connections fail with "unknown host" errors
- ❌ RDP connections fail when using hostnames
- ❌ Ansible inventory hostname resolution fails

### Why This Happened
The setup scripts in `miket-infra-devices` were missing the `--accept-dns` flag:

1. **Linux/macOS script** (`scripts/setup-tailscale.sh`) - Missing `--accept-dns`
2. **Windows script** (`scripts/Setup-Tailscale.ps1`) - Missing `--accept-dns`

Even though the Terraform configuration correctly enables MagicDNS at the tailnet level, **each device must explicitly accept DNS configuration** during enrollment.

### What Was Fixed
✅ **Fixed:** `scripts/setup-tailscale.sh` - Added `--accept-dns` flag  
✅ **Fixed:** `scripts/Setup-Tailscale.ps1` - Added `--accept-dns` flag

---

## 🔧 Remediation Steps

### For Existing Devices (IMMEDIATE ACTION REQUIRED)

All currently enrolled devices need to be reconfigured to accept DNS. Choose the appropriate method:

#### Option 0: Device-Specific Quick-Fix Scripts (EASIEST) ⭐

**Device-specific remediation scripts are available for each device:**

**Windows (Armitage/Wintermute):**
```powershell
# Run as Administrator
cd C:\path\to\miket-infra-devices
.\devices\armitage\scripts\Fix-MagicDNS.ps1
# or
.\devices\wintermute\scripts\Fix-MagicDNS.ps1
```

**Linux (Motoko):**
```bash
cd ~/miket-infra-devices
sudo ./devices/motoko/fix-magicdns.sh
```

**macOS (Count-Zero):**
```bash
cd ~/miket-infra-devices
./devices/count-zero/fix-magicdns.sh
```

These scripts will:
- ✅ Automatically detect current tags
- ✅ Reset and re-enroll with `--accept-dns`
- ✅ Verify the fix worked
- ✅ Provide next steps for testing

#### Option 1: Re-run Setup Scripts
Re-run the updated setup script on each device:

**Linux/macOS:**
```bash
cd ~/miket-infra-devices
./scripts/setup-tailscale.sh <device-name>
# When prompted to reconfigure, answer 'y'
```

**Windows (PowerShell as Administrator):**
```powershell
cd C:\path\to\miket-infra-devices
.\scripts\Setup-Tailscale.ps1
# When prompted to reconfigure, answer 'y'
```

#### Option 2: Manual Fix (If device-specific scripts aren't available)

**Linux/macOS:**
```bash
# Get current tags
CURRENT_TAGS=$(tailscale status --json | jq -r '.Self.Tags[]?' | tr '\n' ',' | sed 's/,$//')

# Re-enroll with --accept-dns
sudo tailscale up \
  --advertise-tags=$CURRENT_TAGS \
  --accept-dns \
  --ssh \
  --accept-routes
```

**Windows (PowerShell as Administrator):**
```powershell
# Get current tags
$status = tailscale status --json | ConvertFrom-Json
$tags = $status.Self.Tags -join ","

# Re-enroll with --accept-dns
tailscale up --advertise-tags=$tags --accept-routes --accept-dns
```

#### Option 3: One-Liner Fix (Fastest, but less user-friendly)

**Linux/macOS:**
```bash
sudo tailscale up --reset && sudo tailscale up --advertise-tags=$(tailscale status --json | jq -r '.Self.Tags[]?' | tr '\n' ',' | sed 's/,$//') --accept-dns --ssh --accept-routes
```

**Windows:**
```powershell
# Get tags first
$tags = (tailscale status --json | ConvertFrom-Json).Self.Tags -join ","
# Then reset and re-enroll
tailscale up --reset
tailscale up --advertise-tags=$tags --accept-routes --accept-dns
```

---

## ✅ Verification

After remediation, verify MagicDNS is working:

### 1. Check DNS Configuration
```bash
# Linux/macOS
tailscale status --json | jq '.Self.DNS'

# Windows
tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty Self | Select-Object DNS
```

Expected: Should show DNS server `100.100.100.100` or similar.

### 2. Test Hostname Resolution
```bash
# From any device, ping another device by hostname
ping motoko
ping armitage
ping wintermute
ping count-zero

# Should resolve to 100.x.x.x addresses
```

### 3. Test SSH via MagicDNS
```bash
# Should work without IP addresses
ssh mike@miket.io@motoko
ssh root@motoko
```

### 4. Test RDP via MagicDNS (Windows)
```powershell
# Should resolve hostname
Test-NetConnection -ComputerName armitage -Port 3389
Test-NetConnection -ComputerName wintermute -Port 3389
```

---

## 📋 Device Checklist

Use this checklist to track remediation:

- [ ] **motoko** (Linux server, Ansible control node)
  - [ ] Re-enrolled with `--accept-dns`
  - [ ] Verified DNS: `tailscale status --json | jq '.Self.DNS'`
  - [ ] Tested: `ping armitage` resolves
  - [ ] Tested: SSH from other devices works

- [ ] **armitage** (Windows workstation)
  - [ ] Re-enrolled with `--accept-dns`
  - [ ] Verified DNS configuration
  - [ ] Tested: `ping motoko` resolves
  - [ ] Tested: RDP accessible via hostname

- [ ] **wintermute** (Windows workstation)
  - [ ] Re-enrolled with `--accept-dns`
  - [ ] Verified DNS configuration
  - [ ] Tested: `ping motoko` resolves
  - [ ] Tested: RDP accessible via hostname

- [ ] **count-zero** (macOS workstation)
  - [ ] Re-enrolled with `--accept-dns`
  - [ ] Verified DNS configuration
  - [ ] Tested: `ping motoko` resolves
  - [ ] Tested: SSH works

---

## 🛡️ Prevention

### For Future Device Enrollments

1. **Always use the updated setup scripts** - They now include `--accept-dns`
2. **Documentation updated** - All enrollment docs now mention `--accept-dns`
3. **Code review checklist** - Any new Tailscale enrollment code must include `--accept-dns`

### Key Principle
> **MagicDNS must be enabled at TWO levels:**
> 1. ✅ Tailnet level (Terraform) - Already done
> 2. ✅ Device level (`--accept-dns` flag) - NOW FIXED

---

## 📚 References

- [Tailscale MagicDNS Documentation](https://tailscale.com/kb/1081/magicdns/)
- [Tailscale DNS Configuration](https://tailscale.com/kb/1054/dns/)
- Terraform config: `miket-infra/infra/tailscale/entra-prod/main.tf`
- Setup scripts: `miket-infra-devices/scripts/setup-tailscale.sh` and `Setup-Tailscale.ps1`

---

## 🎯 Success Criteria

MagicDNS is fixed when:

- ✅ All devices can ping each other by hostname
- ✅ SSH connections work using hostnames (not just IPs)
- ✅ RDP connections work using hostnames
- ✅ Ansible inventory resolves hostnames correctly
- ✅ `tailscale status --json | jq '.Self.DNS'` shows DNS server on all devices

---

**Next Steps:**
1. Remediate all existing devices (use checklist above)
2. Verify connectivity from CEO's devices
3. Document completion in this file
4. Close incident

