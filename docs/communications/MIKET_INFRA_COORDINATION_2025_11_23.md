---
document_title: "Cross-Project Coordination Request: NoMachine Client Testing & MagicDNS Timeline"
author: "Codex-PM-011 (miket-infra-devices Product Manager)"
last_updated: 2025-11-23
status: Sent to miket-infra
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-miket-infra-coordination
---

# Cross-Project Coordination Request

**From:** miket-infra-devices Product Manager (Codex-PM-011)  
**To:** miket-infra Product Manager & Chief Architect  
**Date:** November 23, 2025  
**Priority:** Medium  
**Type:** Wave 2 Coordination + Blocker Resolution

---

## Executive Summary

Following the first weekly roadmap alignment check, miket-infra-devices team requests coordination on four items:

1. ✅ **NoMachine Client Testing** - Server baseline delivered; ready for client testing
2. ⚠️ **MagicDNS Fix Timeline** - Request ETA for DNS resolution fix
3. ℹ️ **Device Persona Matrix** - Request Cloudflare Access mapping (Wave 2)
4. ℹ️ **Entra Compliance Schema** - Request device evidence format requirements (Wave 2)

**Urgency:** Items 1-2 medium priority (Wave 2 unblocked), items 3-4 low priority (Wave 2 planning)

---

## Request 1: NoMachine Client Testing Coordination

### Context

miket-infra delivered NoMachine server baseline on 2025-11-22:
- ✅ Version: v9.2.18-3
- ✅ Port: 4000 (Tailscale-bound)
- ✅ Servers: motoko (100.92.23.71), wintermute (100.89.63.123), armitage (100.72.64.90)
- ✅ Security: UFW allows Tailscale (100.64.0.0/10), denies elsewhere
- ✅ Service Status: All servers operational, logs healthy

**Device Team Status:**
- ✅ Pre-flight connectivity tests PASSED (2025-11-23):
  - `nc -zv motoko.pangolin-vega.ts.net 4000` → SUCCESS
  - `nc -zv wintermute.pangolin-vega.ts.net 4000` → SUCCESS
  - `nc -zv armitage.pangolin-vega.ts.net 4000` → SUCCESS
- ✅ Testing procedure documented: `docs/runbooks/nomachine-client-testing.md`
- 🚧 NoMachine client installation on count-zero: IN PROGRESS
- 🚧 End-to-end connection testing: PENDING client installation

### Request

**Coordinate NoMachine client testing from count-zero (macOS) to all three servers**

**Testing Timeline:**
- Week of 2025-11-25: Install NoMachine client on count-zero
- Week of 2025-11-25: Execute end-to-end connection tests (motoko, wintermute, armitage)
- Week of 2025-11-25: Share test results with miket-infra team

**What We Need:**
1. ✅ **Confirmation:** Server-side NoMachine is ready for client testing (CONFIRMED via connectivity tests)
2. ⚠️ **Logs Access:** If connection issues arise, we may need server-side NoMachine logs
3. ℹ️ **Expected Behavior:** Confirm expected auth flow (username/password → desktop session)
4. ℹ️ **Performance Baseline:** What latency/quality is expected over Tailscale?

**What We'll Provide:**
1. Test results report (connection success rate, latency, quality, issues)
2. Client-side logs/screenshots if connection fails
3. MagicDNS status (working vs. IP fallback required)
4. Performance metrics (connection time, bandwidth, session quality)

### Success Criteria

**PASS:** All 3 servers connectable, session quality "Good" or better, <10s connection time  
**FAIL:** Any server unreachable, session quality "Poor", or blocker bugs discovered

---

## Request 2: MagicDNS Fix Timeline

### Context

**Current Status:**
- ⚠️ Tailscale ACLs verified and working correctly (2025-11-23 alignment check)
- ⚠️ MagicDNS resolution unreliable for SMB mounts
- ✅ Workaround operational: LAN IP fallback (192.168.1.195)
- ⚠️ Device mounts currently use LAN IPs instead of Tailscale DNS hostnames

**Impact:**
- **DEV-002** partially blocked (ACL verified; DNS fix pending)
- Device mounts work via LAN fallback, but prefer Tailscale DNS for resilience
- NoMachine testing will validate if MagicDNS works for port 4000 connections

**Test Results (2025-11-23):**
```bash
# NoMachine connectivity tests used MagicDNS hostnames:
nc -zv motoko.pangolin-vega.ts.net 4000       # ✅ SUCCESS
nc -zv wintermute.pangolin-vega.ts.net 4000   # ✅ SUCCESS
nc -zv armitage.pangolin-vega.ts.net 4000     # ✅ SUCCESS

# MagicDNS appears to be working for NoMachine connections
# Will validate for SMB (port 445) separately
```

### Request

**Provide estimated timeline for MagicDNS resolution fix (if still needed)**

**Questions:**
1. Is MagicDNS known to have issues with SMB (port 445) specifically?
2. Do NoMachine tests (port 4000) indicate MagicDNS is working generally?
3. Should device team retest SMB mounts with Tailscale DNS instead of LAN IPs?
4. If MagicDNS fix is complex, can we document LAN fallback as permanent solution?

**Priority:** Medium (workaround operational, but want to validate if DNS is truly broken or SMB-specific)

### Proposed Next Steps

1. Device team retests SMB mounts using Tailscale hostnames (not LAN IPs)
2. If SMB mounts work via MagicDNS, update playbooks to use Tailscale hostnames
3. If SMB mounts fail via MagicDNS but NoMachine works, escalate SMB-specific DNS issue
4. If all services work via MagicDNS, close DEV-002 as "workaround no longer needed"

---

## Request 3: Device Persona Matrix (Wave 2 - Low Priority)

### Context

**Wave 2 Focus:** Remote access UX (NoMachine client standardization, Cloudflare Access alignment)

**DEV-007 Task:** Map Cloudflare Access + device personas for remote app access

**Current Understanding:**
- Cloudflare Access integrated with Entra ID OIDC (2025-11-23)
- Device personas needed: workstation, server, mobile (potentially)
- Access policies map personas to applications (NoMachine, admin tools, etc.)

### Request

**Publish Cloudflare Access device persona mapping by Wave 2 kickoff (Jan 2026)**

**What We Need:**
1. Device persona taxonomy (workstation, server, mobile, etc.)
2. Mapping of personas to Cloudflare Access groups
3. Access policy matrix (which personas can access which apps)
4. Device certificate enrollment requirements (if applicable)

**What We'll Provide:**
1. Device inventory mapped to personas (motoko=server, wintermute/armitage=workstation, etc.)
2. Device onboarding playbooks updated to assign personas during enrollment
3. Device compliance evidence aligned with persona requirements

**Timeline:** Request by **December 15, 2025** for Wave 2 planning (execution Jan 2026)

---

## Request 4: Entra Compliance Schema (Wave 2 - Low Priority)

### Context

**Wave 2 Focus:** Conditional Access automation & observability SLOs

**DEV-006 Task:** Define compliance attestations (FileVault, BitLocker, EDR) and evidence storage

**Current Understanding:**
- Entra Conditional Access policies gate device access based on compliance signals
- Device team storing evidence in `/space/devices/<host>/compliance`
- Evidence format must match miket-infra dashboard query expectations

### Request

**Share Entra device compliance signal schema and evidence format requirements**

**What We Need:**
1. Compliance signal types (FileVault status, BitLocker status, EDR status, OS version, etc.)
2. Evidence file format (JSON, YAML, CSV, etc.)
3. Required fields per signal type
4. Update frequency (real-time, hourly, daily?)
5. Integration method (Azure Monitor, direct Entra API, file-based?)

**What We'll Provide:**
1. Device playbooks to collect compliance signals
2. Evidence files stored in `/space/devices/<host>/compliance/`
3. Scheduled tasks to update evidence (hourly/daily)
4. Validation playbooks to verify evidence format

**Timeline:** Request by **December 15, 2025** for Wave 2 planning (execution Jan 2026)

---

## Response Requested

### Immediate (Week of 2025-11-25)

1. ✅ **Acknowledge NoMachine client testing coordination** (quick reply)
2. ⚠️ **Provide MagicDNS status clarification** (working for NoMachine; check SMB?)
3. ℹ️ **Confirm expected NoMachine behavior** (auth flow, performance baseline)

### Near-Term (Week of 2025-12-02)

4. ℹ️ **Share device persona matrix** (or draft) for Wave 2 planning
5. ℹ️ **Share Entra compliance schema** (or draft) for Wave 2 planning

### Monthly Review (2025-12-02)

6. ✅ **Joint monthly deep review** - Full integration point verification
7. ✅ **Wave 2 dependency alignment** - Confirm timing and deliverables

---

## Contact Information

**Device Team Contacts:**
- **Product Manager:** Codex-PM-011 (miket-infra-devices)
- **Chief Architect:** Codex-CA-001 (miket-infra-devices)
- **macOS Engineer:** Codex-MAC-012 (NoMachine client testing lead)

**Preferred Communication:**
- Cross-post to both COMMUNICATION_LOGs (miket-infra, miket-infra-devices)
- Weekly alignment check updates (every Monday)
- Monthly deep review (first Monday, 2 hours)

---

## Appendix: Test Results Summary

### NoMachine Server Connectivity (2025-11-23)

**Pre-Flight Tests from count-zero:**

```
Test: nc -zv motoko.pangolin-vega.ts.net 4000
Result: ✅ SUCCESS
IP: 100.92.23.71
Transport: Tailscale (MagicDNS resolved successfully)

Test: nc -zv wintermute.pangolin-vega.ts.net 4000
Result: ✅ SUCCESS
IP: 100.89.63.123
Transport: Tailscale (MagicDNS resolved successfully)

Test: nc -zv armitage.pangolin-vega.ts.net 4000
Result: ✅ SUCCESS
IP: 100.72.64.90
Transport: Tailscale (MagicDNS resolved successfully)
```

**Assessment:**
- ✅ All servers reachable on port 4000
- ✅ MagicDNS resolving correctly for NoMachine hostnames
- ✅ Tailscale routing operational
- ✅ Server-side NoMachine ready for client connections

**Next Step:** Install NoMachine client on count-zero and execute full connection tests

---

## Related Documentation

- [Weekly Alignment Report 2025-11-23](./WEEKLY_ALIGNMENT_2025_11_23.md)
- [NoMachine Client Testing Procedure](../runbooks/nomachine-client-testing.md)
- [DAY0 Backlog](../product/DAY0_BACKLOG.md) - DEV-010, DEV-011, DEV-012
- [V1.0 Roadmap](../product/V1_0_ROADMAP.md) - Wave 2 dependencies

---

**End of Coordination Request**

