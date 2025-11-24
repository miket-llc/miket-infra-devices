---
document_title: "Certificate Enrollment Role Documentation"
author: "Codex-SEC-004 (Security/IAM Engineer)"
last_updated: 2025-11-24
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-24-wave2-certificate-enrollment
---

# Certificate Enrollment Role

**Purpose:** Automate Cloudflare WARP/Gateway certificate enrollment for Cloudflare Access authentication across all device platforms.

**Status:** ✅ **PUBLISHED** - miket-infra coordination response received (2025-11-24)

**Important:** Certificate enrollment **NOT REQUIRED** for current Cloudflare Access architecture. This role is available for future use if Cloudflare Gateway is deployed.

---

## Overview

This Ansible role automates certificate enrollment for Cloudflare Access authentication using Cloudflare WARP client. It supports:

- **macOS:** Homebrew installation and enrollment
- **Windows:** MSI installation and enrollment
- **Linux:** APT repository installation and enrollment

---

## Prerequisites

**Current Architecture:** Certificate enrollment **NOT REQUIRED**

**Rationale:** Cloudflare Access uses Entra ID OIDC authentication with session cookies. Device certificates are not required for application-level access control.

**Future Requirements (if Cloudflare Gateway deployed):**
- Cloudflare WARP organization name
- Enrollment key (if required)
- Certificate authority (CA) details
- Enrollment URL

**Current Status:** ✅ **NOT REQUIRED** - Role available for future use if Cloudflare Gateway is deployed

---

## Role Variables

### Required Variables

```yaml
# Cloudflare WARP configuration (TBD - awaiting miket-infra)
cloudflare_warp_organization: ""  # Organization name
cloudflare_warp_enrollment_key: ""  # Enrollment key (if required)
```

### Optional Variables

```yaml
# Enable/disable certificate enrollment
certificate_enrollment_enabled: true

# Platform-specific enablement
certificate_enrollment_macos_enabled: true
certificate_enrollment_windows_enabled: true
certificate_enrollment_linux_enabled: true

# Validation settings
certificate_validation_enabled: true
certificate_validation_interval: 86400  # 24 hours
```

---

## Usage

### Deploy to All Devices

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/enroll-certificates.yml
```

### Deploy to Specific Platform

```bash
# macOS only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/enroll-certificates.yml --limit macos

# Windows only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/enroll-certificates.yml --limit windows

# Linux only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/enroll-certificates.yml --limit linux
```

### Deploy to Single Device

```bash
# Example: count-zero (macOS)
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/enroll-certificates.yml --limit count-zero
```

---

## Platform-Specific Implementation

### macOS

**Installation Method:** Homebrew  
**Client:** Cloudflare WARP (`cloudflare-warp`)  
**Commands:**
- `warp-cli register` - Register device
- `warp-cli set-mode warp` - Set WARP mode
- `warp-cli connect` - Connect to WARP
- `warp-cli status` - Check status

### Windows

**Installation Method:** MSI installer  
**Client:** Cloudflare WARP (`cloudflare-warp`)  
**Location:** `C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe`  
**Commands:** Same as macOS (via PowerShell)

### Linux

**Installation Method:** APT repository  
**Client:** Cloudflare WARP (`cloudflare-warp`)  
**Repository:** `https://pkg.cloudflareclient.com/`  
**Commands:** Same as macOS

---

## Validation

### Check Certificate Enrollment Status

```bash
# macOS/Linux
warp-cli status

# Windows
& "C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe" status
```

### Expected Output

```
Status update: Connected
Successfully registered
```

---

## Troubleshooting

### WARP Not Connecting

**Symptoms:** `warp-cli status` shows "Disconnected"

**Resolution:**
1. Check network connectivity
2. Verify Cloudflare WARP organization name
3. Check enrollment key (if required)
4. Review Cloudflare Access policy configuration

### Certificate Enrollment Fails

**Symptoms:** `warp-cli register` fails

**Resolution:**
1. Verify Cloudflare WARP organization name
2. Check enrollment key (if required)
3. Verify device has internet connectivity
4. Check Cloudflare Access configuration

---

## Related Documentation

- [Cloudflare Access Mapping](../../docs/runbooks/cloudflare-access-mapping.md)
- [Wave 2 Coordination Response](../../docs/communications/WAVE2_COORDINATION_RESPONSE_RECEIVED.md)
- [Wave 2 Coordination Requests](../../docs/communications/WAVE2_MIKET_INFRA_COORDINATION.md)
- [Certificate Enrollment Playbook](../playbooks/enroll-certificates.yml)

---

**End of Certificate Enrollment Role Documentation**

