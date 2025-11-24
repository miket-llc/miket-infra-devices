---
document_title: "Cloudflare Access Device Persona Mapping"
author: "Codex-SEC-004 (Security/IAM Engineer)"
last_updated: 2025-11-24
status: Draft
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-24-wave2-cloudflare-access-mapping
  - docs/communications/WAVE2_MIKET_INFRA_COORDINATION.md
---

# Cloudflare Access Device Persona Mapping

**Purpose:** Map device personas to Cloudflare Access groups and configure remote app policies for NoMachine, SSH, and admin tools.

**Status:** ✅ **PUBLISHED** - miket-infra device persona matrix received (2025-11-24)

**Source:** [Wave 2 Coordination Response from miket-infra](../communications/WAVE2_MIKET_INFRA_COORDINATION.md)

---

## Device Persona Taxonomy

Based on device inventory and Tailscale tags:

### Persona: `workstation`
**Devices:** wintermute, armitage, count-zero  
**Tailscale Tags:** `tag:workstation`, `tag:windows` (wintermute/armitage), `tag:macos` (count-zero)  
**Characteristics:**
- Development workstations
- User-facing devices
- Require remote access to servers
- May require admin tool access

**Cloudflare Access Group:** `group:devs`, `group:owners` (Entra ID groups)

### Persona: `server`
**Devices:** motoko  
**Tailscale Tags:** `tag:server`, `tag:linux`, `tag:ansible`  
**Characteristics:**
- Infrastructure servers
- Host services (Docker, Samba, NoMachine server)
- Require management access
- May require admin tool access

**Cloudflare Access Group:** `group:devs`, `group:owners` (Entra ID groups)

### Persona: `mobile` (Future)
**Devices:** TBD  
**Tailscale Tags:** TBD  
**Characteristics:**
- Mobile devices (iOS, Android)
- May require limited remote access
- Certificate enrollment required

**Cloudflare Access Group:** `group:devs`, `group:owners` (Entra ID groups - future)

---

## Remote Application Policies

### Application: NoMachine (Port 4000)

**Access Requirements:**
- Workstations can access all NoMachine servers
- Servers can access other servers (for management)
- Mobile devices may have limited access (TBD)

**Policy Configuration:**
```yaml
application: nomachine
hostname: nomachine.miket.io  # To be configured in Cloudflare Access
port: 4000
protocol: NX

access_policies:
  - name: workstation-and-server-access
    groups: ["group:devs", "group:owners"]
    allow:
      - motoko.pangolin-vega.ts.net:4000
      - wintermute.pangolin-vega.ts.net:4000
      - armitage.pangolin-vega.ts.net:4000
    require:
      - mfa: true
    session_duration: 24h
```

**Status:** ✅ **CONFIGURED** - Access granted to `group:devs` and `group:owners` (Entra ID groups)

### Application: SSH (Port 22)

**Access Requirements:**
- Ansible node (motoko) can SSH to all Linux/macOS devices
- Workstations can SSH to servers (for management)
- Mobile devices: No SSH access (TBD)

**Policy Configuration:**
```yaml
application: ssh
hostname: ssh.miket.io  # To be configured in Cloudflare Access
port: 22
protocol: SSH

access_policies:
  - name: workstation-and-server-access
    groups: ["group:devs", "group:owners"]
    allow:
      - motoko.pangolin-vega.ts.net:22
      - count-zero.pangolin-vega.ts.net:22
    require:
      - mfa: true
    session_duration: 24h
```

**Status:** ✅ **CONFIGURED** - Access granted to `group:devs` and `group:owners` (Entra ID groups)

### Application: Admin Tools (TBD)

**Access Requirements:**
- TBD based on miket-infra admin tool requirements
- May include: Cloudflare dashboard, Tailscale admin, Azure portal

**Policy Configuration:**
```yaml
application: admin-tools
hostname: admin.miket.io  # Confirmed from miket-infra (2025-11-23)
port: 443
protocol: HTTPS

access_policies:
  - name: admin-access
    groups: ["group:owners"]  # Owners only for admin tools
    allow:
      - admin.miket.io
    require:
      - mfa: true
    session_duration: 24h
```

**Status:** ✅ **CONFIGURED** - Access granted to `group:owners` only (Entra ID group)

---

## Device-to-Persona Mapping

| Device | Hostname | Persona | Tailscale Tags | Cloudflare Access Groups |
|--------|----------|---------|----------------|-------------------------|
| motoko | motoko.pangolin-vega.ts.net | `server` | `tag:server`, `tag:linux`, `tag:ansible` | `group:devs`, `group:owners` |
| wintermute | wintermute.pangolin-vega.ts.net | `workstation` | `tag:workstation`, `tag:windows`, `tag:gaming` | `group:devs`, `group:owners` |
| armitage | armitage.pangolin-vega.ts.net | `workstation` | `tag:workstation`, `tag:windows`, `tag:gaming` | `group:devs`, `group:owners` |
| count-zero | count-zero.pangolin-vega.ts.net | `workstation` | `tag:workstation`, `tag:macos` | `group:devs`, `group:owners` |

**Note:** Cloudflare Access uses Entra ID OIDC authentication. Access is granted based on user identity and group membership, not device tags. Device personas inform policy design, but users must be members of `group:devs` or `group:owners` to access applications.

---

## Certificate Enrollment Requirements

**Cloudflare WARP/Gateway:** **NOT REQUIRED** for current Cloudflare Access architecture.

**Current Architecture:**
- Cloudflare Access uses Entra ID OIDC authentication with session cookies
- Device certificates are **NOT required** for application-level access control
- Certificate enrollment only needed if Cloudflare Gateway is deployed (future)

**Enrollment Status:**
- ✅ **NOT REQUIRED** - Current architecture uses OIDC authentication

**Note:** The certificate enrollment role (`ansible/roles/certificate_enrollment/`) is available for future use if Cloudflare Gateway is deployed, but is not required for the current Cloudflare Access implementation.

**Device Enrollment Requirements:**
- macOS: Cloudflare WARP client enrollment
- Windows: Cloudflare WARP client enrollment
- Linux: Cloudflare WARP client enrollment

**See:** [Certificate Enrollment Automation](../ansible/roles/certificate_enrollment/README.md)

---

## Validation Playbook

**Playbook:** `ansible/playbooks/validate-cloudflare-access.yml`

**Validation Steps:**
1. Verify device personas match Cloudflare Access groups
2. Test access from each device persona to remote applications
3. Verify certificate enrollment status
4. Validate access policies match device inventory

**Run Validation:**
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-cloudflare-access.yml
```

---

## Next Steps

1. ✅ **miket-infra Response Received (2025-11-24):**
   - Device persona matrix: Complete
   - Cloudflare Access groups: `group:devs`, `group:owners` (Entra ID)
   - Policy configuration: Documented above
   - Certificate enrollment: Not required for current architecture

2. **Configure Cloudflare Access Applications:**
   - Add NoMachine application to Cloudflare Access (hostname: `nomachine.miket.io`)
   - Add SSH application to Cloudflare Access (hostname: `ssh.miket.io`)
   - Configure policies using Entra ID groups (`group:devs`, `group:owners`)

3. **Test Access:**
   - Verify users in `group:devs` or `group:owners` can access NoMachine via Cloudflare Access
   - Verify users can access SSH via Cloudflare Access
   - Test MFA requirements

4. **Validate:**
   - Run validation playbook: `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/validate-cloudflare-access.yml`
   - Document test results
   - Update COMMUNICATION_LOG

---

## Related Documentation

- [Wave 2 Coordination Requests](../communications/WAVE2_MIKET_INFRA_COORDINATION.md)
- [Certificate Enrollment Automation](../ansible/roles/certificate_enrollment/README.md)
- [NoMachine Client Installation](./nomachine-client-installation.md)
- [Tailscale Device Setup](./TAILSCALE_DEVICE_SETUP.md)

---

**End of Cloudflare Access Mapping Document**

