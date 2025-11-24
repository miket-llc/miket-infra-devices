---
document_title: "Wave 2: miket-infra Coordination Requests"
author: "Codex-PM-011 (Product Manager)"
last_updated: 2025-11-24
status: Draft
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-24-wave2-coordination
---

# Wave 2: miket-infra Coordination Requests

## Context

**Wave 2 Focus:** Cloudflare Access Mapping & Remote Access UX Enhancement  
**Initiative:** Complete device persona mapping to Cloudflare Access policies, implement certificate enrollment, and establish Tailscale ACL drift checks.

**Current Status:**
- ✅ Wave 1 complete (v1.7.0): NoMachine standardized, RDP/VNC removed
- ✅ NoMachine servers operational (motoko, wintermute, armitage on port 4000)
- ✅ Tailscale ACL alignment verified (device tags match ACL tagOwners)
- ⚠️ Cloudflare Access device persona matrix pending from miket-infra
- ⚠️ Certificate enrollment not configured
- ⚠️ Tailscale ACL drift checks not automated

## Request 1: Cloudflare Access Device Persona Matrix

### Context

**DEV-007 Task:** Map Cloudflare Access + device personas for remote app access

**Device Personas Identified:**
- `workstation` - Development workstations (wintermute, armitage, count-zero)
- `server` - Infrastructure servers (motoko)
- `mobile` - Mobile devices (if applicable)

**Current Understanding:**
- Cloudflare Access integrated with Entra ID OIDC (2025-11-23)
- Device personas needed for access policy mapping
- Remote applications: NoMachine (port 4000), SSH (port 22), admin tools

### Request

**Publish Cloudflare Access device persona mapping document by Wave 2 completion (Jan 2026)**

**What We Need:**
1. Device persona taxonomy (workstation, server, mobile, etc.)
2. Mapping of personas to Cloudflare Access groups
3. Access policy matrix (which personas can access which apps)
4. Certificate enrollment requirements (Cloudflare WARP/Gateway)

**Priority:** High (blocks DEV-007 completion)

## Request 2: Cloudflare Access Policy Documentation

### Context

**DEV-007 Task:** Configure remote app policies (NoMachine, SSH)

**Current Understanding:**
- Cloudflare Access policies control access to applications behind Cloudflare Zero Trust
- Policies use group-based access rules
- Certificate-based authentication may be required

### Request

**Provide Cloudflare Access policy configuration documentation:**

1. Current policy configuration for remote applications
2. Policy syntax and group management procedures
3. Application configuration (NoMachine, SSH, admin tools)
4. Certificate enrollment procedures (Cloudflare WARP/Gateway)

**Priority:** High (blocks DEV-007 completion)

## Request 3: Certificate Enrollment Requirements

### Context

**DEV-013 Task:** Implement certificate enrollment automation

**Current Understanding:**
- Cloudflare WARP/Gateway may require certificate enrollment
- Device certificates needed for Cloudflare Access authentication
- Enrollment automation required for all device personas

### Request

**Provide certificate enrollment requirements:**

1. Cloudflare WARP/Gateway certificate enrollment procedures
2. Certificate authority (CA) details
3. Enrollment automation requirements (API endpoints, authentication)
4. Platform-specific enrollment procedures (macOS, Windows, Linux)

**Priority:** Medium (blocks DEV-013 completion)

## Request 4: Tailscale ACL State Access

### Context

**DEV-014 Task:** Create Tailscale ACL drift check automation

**Current Understanding:**
- Tailscale ACLs managed by miket-infra via Terraform
- Device tags must align with ACL tagOwners
- Drift detection requires comparing device inventory vs ACL state

### Request

**Provide access to Tailscale ACL state for drift detection:**

1. Terraform state access (read-only) or API endpoint
2. ACL JSON structure documentation
3. Device tag mapping format
4. SSH and port rule structure

**Priority:** Medium (blocks DEV-014 completion)

## Request 5: Wave 2 Deliverables Timeline

### Context

**Wave 2 Target Completion:** January 2026

**Dependencies:**
- Cloudflare Access device persona matrix
- Certificate enrollment requirements
- Tailscale ACL state access

### Request

**Provide estimated timeline for Wave 2 deliverables:**

1. Cloudflare Access device persona matrix delivery date
2. Certificate enrollment documentation delivery date
3. Any blockers or dependencies affecting Wave 2 timeline

**Priority:** Low (informational, for planning)

## Next Steps

1. **Device Team Actions:**
   - Document coordination requests in COMMUNICATION_LOG
   - Create placeholder Cloudflare Access mapping based on device inventory
   - Proceed with certificate enrollment automation (generic implementation)
   - Create Tailscale ACL drift check playbook (using available information)

2. **miket-infra Team Actions:**
   - Review coordination requests
   - Provide device persona matrix and policy documentation
   - Share certificate enrollment requirements
   - Provide Tailscale ACL state access method

3. **Follow-up:**
   - Update DEV-007, DEV-013, DEV-014 with miket-infra responses
   - Complete Cloudflare Access mapping once persona matrix received
   - Finalize certificate enrollment automation with miket-infra requirements
   - Validate Tailscale ACL drift checks with miket-infra ACL state

---

## Coordination Log

**2025-11-24:** Initial coordination request created  
**Status:** Awaiting miket-infra response  
**Next Review:** Weekly alignment check (2025-11-25)

