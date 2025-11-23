---
document_title: "miket-infra-devices Roadmap Alignment Protocol"
author: "Codex-PM-011 (miket-infra-devices Product Manager)"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-roadmap-alignment-protocol
---

# Roadmap Alignment Protocol

## Purpose

This protocol ensures continuous alignment between **miket-infra-devices** v1.0 roadmap and **miket-infra** v2.0 platform roadmap. It defines validation checklists, review cadences, and escalation paths for dependency management.

## Cross-Project Integration Points

### 1. Tailscale Network & ACLs

**Owned by:** miket-infra (Terraform-managed ACL policies)  
**Consumed by:** miket-infra-devices (device tagging, SSH enablement, connectivity)

**Integration Requirements:**
- Device tags must align with miket-infra ACL `tagOwners` definitions
- Tailscale SSH enablement respects ACL `ssh` rules
- MagicDNS configuration matches miket-infra DNS settings
- Device enrollment uses auth keys from miket-infra Terraform outputs

**Dependencies:**
- DEV-002: Tailscale ACL alignment validation + MagicDNS fix
- Wave 1: Tailscale ACL freeze dates
- Wave 2: Updated ACLs for NoMachine routing

**Validation:**
```bash
# Run from miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-tailscale-acl-alignment.yml
```

### 2. Entra ID Device Compliance & Conditional Access

**Owned by:** miket-infra (Entra ID policies, Conditional Access rules)  
**Consumed by:** miket-infra-devices (device compliance attestation, evidence storage)

**Integration Requirements:**
- Device compliance signals (FileVault, BitLocker, EDR) match Entra CA policy requirements
- Compliance evidence stored in `/space/devices/<host>/compliance` with format expected by miket-infra dashboards
- Device registration in Entra ID completed during onboarding

**Dependencies:**
- DEV-006: Compliance attestations aligned with Entra feed format
- Wave 1: Entra ID device compliance signals availability
- Wave 3: Entra/Conditional Access policies finalized

**Validation:**
```bash
# Check compliance evidence format
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-compliance-evidence.yml
```

### 3. Cloudflare Access & Application Policies

**Owned by:** miket-infra (Cloudflare Zero Trust policies)  
**Consumed by:** miket-infra-devices (device persona mapping, remote app access)

**Integration Requirements:**
- Device personas (workstation, server, mobile) mapped to Cloudflare Access groups
- Remote access applications (NoMachine, RDP, SSH) match Cloudflare policy rules
- Device certificate enrollment aligned with Cloudflare WARP/Gateway

**Dependencies:**
- DEV-007: Cloudflare Access + device persona mapping
- Wave 2: Cloudflare Access posture and application matrix
- Wave 2: NoMachine server config + ACLs

**Validation:**
- Manual review of Cloudflare Access policies vs device inventory
- Test remote access from each device persona

### 4. Azure Monitor & Observability Pipelines

**Owned by:** miket-infra (Azure Monitor workspaces, Log Analytics, dashboards)  
**Consumed by:** miket-infra-devices (device telemetry, mount/sync health, remote access metrics)

**Integration Requirements:**
- Device agents ship logs to miket-infra Azure Monitor workspace
- Log schema matches miket-infra query expectations (mounts, sync, remote access)
- Alerting rules coordinate with miket-infra Ops channel
- Device health metrics visible in miket-infra dashboards

**Dependencies:**
- DEV-008: Azure Monitor/observability plan for devices
- Wave 3: Azure Monitor workspace IDs and ingestion rules
- Wave 3: miket-infra dashboards for shared view
- Wave 3: Audit log retention policies

**Validation:**
```bash
# Test log shipping from device to Azure Monitor
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-azure-monitor-integration.yml
```

### 5. NoMachine Server Configuration

**Owned by:** miket-infra (NoMachine server deployment, firewall baselines, network routing)  
**Consumed by:** miket-infra-devices (NoMachine client standardization, connection profiles)

**Integration Requirements:**
- NoMachine client configuration matches server version and protocol
- Connection profiles use correct server endpoints (Tailscale, LAN fallback)
- Firewall rules coordinate between server (miket-infra) and client (miket-infra-devices)
- Session management aligns with server capacity planning

**Dependencies:**
- DEV-005: NoMachine client/server config standardization
- Wave 2: NoMachine server images and firewall baselines from miket-infra
- Wave 2: LiteLLM/L4 routing updates (if applicable)

**Validation:**
- End-to-end NoMachine connection test from each device type
- Latency and throughput benchmarks

---

## Roadmap Alignment Validation Checklist

### Weekly Alignment Check (Every Monday)

**Owner:** Codex-PM-011 (miket-infra-devices Product Manager)  
**Duration:** 30 minutes  
**Artifacts:** Update to COMMUNICATION_LOG.md with alignment status

#### Checklist:

- [ ] **Review miket-infra COMMUNICATION_LOG.md** for decisions affecting devices
  - Check for ACL policy changes
  - Check for Entra/Conditional Access updates
  - Check for Cloudflare Access policy changes
  - Check for Azure Monitor workspace changes
  - Check for NoMachine server updates

- [ ] **Update device roadmap** if miket-infra dependencies change
  - Adjust wave timing if blockers introduced
  - Add new dependencies to DAY0_BACKLOG.md
  - Update EXECUTION_TRACKER.md with blocker status

- [ ] **Document alignment status** in device COMMUNICATION_LOG.md
  - Create weekly alignment entry with date anchor
  - List miket-infra changes reviewed
  - Note any roadmap adjustments made
  - Flag escalations for monthly review

**Template:**
```markdown
## YYYY-MM-DD – Weekly Roadmap Alignment Check {#YYYY-MM-DD-weekly-alignment}

### miket-infra Changes Reviewed
- [List changes from miket-infra COMMUNICATION_LOG]

### Impact on Device Roadmap
- [None | Minor | Significant]
- [Description of impact]

### Actions Taken
- [Roadmap updates, blocker escalations, dependency additions]

### Next Review
- [Date of next weekly check]
```

### Monthly Deep Review (First Monday of Month)

**Owner:** Codex-CA-001 (Chief Architect) + Codex-PM-011 (Product Manager)  
**Duration:** 2 hours  
**Artifacts:** Monthly Alignment Report in COMMUNICATION_LOG.md

#### Checklist:

- [ ] **Full cross-project roadmap comparison**
  - Compare miket-infra v2.0 wave timing vs device v1.0 waves
  - Validate wave sequencing (devices don't block infra; infra provides needed capabilities)
  - Check for new initiatives in miket-infra that affect devices

- [ ] **Dependency sequencing validation**
  - Review all device tasks blocked on miket-infra dependencies
  - Validate miket-infra delivery dates vs device consumption dates
  - Identify critical path items and slack in schedule

- [ ] **Timeline conflict resolution**
  - Flag waves where miket-infra and devices overlap on shared resources
  - Resolve conflicts (stagger deployments, request miket-infra priority shift)
  - Document agreed resolution in both COMMUNICATION_LOGs

- [ ] **Integration point verification**
  - Test Tailscale connectivity and ACL enforcement
  - Verify Entra compliance feed availability (if Wave 3)
  - Check Cloudflare Access policy alignment (if Wave 2+)
  - Validate Azure Monitor log ingestion (if Wave 3+)
  - Test NoMachine server connectivity (if Wave 2+)

- [ ] **Update both roadmaps** with alignment decisions
  - Document dependency resolution in miket-infra-devices COMMUNICATION_LOG
  - Coordinate with miket-infra Product Manager to update their log
  - Adjust wave planning tables if timing shifts

**Template:**
```markdown
## YYYY-MM-DD – Monthly Roadmap Deep Review {#YYYY-MM-DD-monthly-review}

### Roadmap Comparison Summary
- miket-infra v2.0 status: [Wave X in progress, Wave Y planned]
- miket-infra-devices v1.0 status: [Wave X in progress, Wave Y planned]
- Alignment: [Aligned | Minor drift | Significant drift]

### Dependency Status
| Device Task | miket-infra Dependency | Status | Risk |
|-------------|------------------------|--------|------|
| DEV-XXX     | [Dependency]           | [On track|Delayed|At risk] | [H|M|L] |

### Integration Point Verification
- Tailscale: [Status, test results]
- Entra ID: [Status, test results]
- Cloudflare: [Status, test results]
- Azure Monitor: [Status, test results]
- NoMachine: [Status, test results]

### Conflicts & Resolutions
- [Description of conflict]
- [Resolution agreed with miket-infra PM]

### Actions Taken
- [Roadmap updates, timing adjustments, escalations]

### Next Review
- [Date of next monthly review]
```

### Quarterly Strategic Review (Aligned with miket-infra Quarterly Updates)

**Owner:** Codex-PM-011 (Product Manager) + Codex-CA-001 (Chief Architect)  
**Duration:** 4 hours  
**Artifacts:** Quarterly Roadmap Update document in docs/product/

#### Checklist:

- [ ] **Review device OKR progress** against miket-infra objectives
  - Compare device KRs vs miket-infra platform maturity
  - Identify gaps where devices lag or lead platform
  - Assess whether device capabilities enable infra objectives

- [ ] **Adjust wave planning** based on miket-infra progress
  - Shift wave timing if miket-infra dependencies delayed
  - Accelerate waves if miket-infra capabilities delivered early
  - Add new waves for emergent miket-infra features

- [ ] **Update strategic priorities** and dependencies
  - Reflect miket-infra platform v2.1+ vision in device roadmap
  - Identify new integration points from miket-infra roadmap
  - Plan device capabilities needed for future infra waves

- [ ] **Document lessons learned** and process improvements
  - Review past quarter's alignment effectiveness
  - Identify process gaps (late discovery of conflicts, missed dependencies)
  - Update alignment protocol with improvements

- [ ] **Publish quarterly roadmap update** document
  - Create `docs/product/QUARTERLY_UPDATE_YYYY_QX.md`
  - Include OKR progress, wave adjustments, strategic shifts
  - Link from COMMUNICATION_LOG with quarterly review anchor

**Template:**
```markdown
---
document_title: "miket-infra-devices Quarterly Update YYYY-QX"
author: "Codex-PM-011"
last_updated: YYYY-MM-DD
status: Published
related_initiatives: [all active initiatives]
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#YYYY-MM-DD-quarterly-review
---

# Quarterly Update YYYY-QX

## Executive Summary
- [High-level progress vs plan]
- [Major achievements]
- [Key challenges and resolutions]

## OKR Progress
| Objective | Key Results | Status | Notes |
|-----------|-------------|--------|-------|
| O1        | KR1, KR2, KR3 | [%] | [Details] |

## Wave Progress & Adjustments
- Wave X: [Status, outcomes, lessons learned]
- Wave Y: [Status, adjustments, new dependencies]

## miket-infra Alignment
- [Summary of alignment over quarter]
- [Major dependency resolutions]
- [New integration points]

## Strategic Shifts
- [Changes to vision, scope, or priorities]
- [New miket-infra capabilities adopted]
- [Device capabilities contributed to infra]

## Lessons Learned
- [Process improvements]
- [Technical insights]
- [Collaboration wins/challenges]

## Next Quarter Plan
- [Updated wave focus]
- [New dependencies from miket-infra roadmap]
- [Resource or budget needs]
```

---

## Escalation Paths

### Blocker Escalation (Immediate)

**Trigger:** Device task blocked by missing miket-infra capability  
**Owner:** Codex-PM-011 (Product Manager)  
**Action:**
1. Document blocker in EXECUTION_TRACKER.md with Impact/Owner/Dependency
2. Create COMMUNICATION_LOG entry with blocker details
3. Contact miket-infra Product Manager directly (same-day)
4. Request delivery date or workaround
5. Update device roadmap with blocker status and mitigation plan

**Template:**
```markdown
## YYYY-MM-DD – Blocker Escalation: [Task ID] {#YYYY-MM-DD-blocker-[task-id]}

### Blocker Details
- **Task:** [DEV-XXX: Description]
- **Dependency:** [miket-infra capability/deliverable]
- **Impact:** [Wave delay, feature scope reduction, workaround required]
- **Risk:** [High|Medium|Low]

### Escalation to miket-infra
- **Date:** YYYY-MM-DD
- **Contact:** miket-infra Product Manager
- **Request:** [Delivery date, workaround, priority adjustment]

### Resolution
- **Response:** [miket-infra PM response]
- **Mitigation:** [Workaround, schedule adjustment, scope change]
- **Outcome:** [Blocker resolved, accepted delay, alternative approach]

### Roadmap Impact
- [Wave timing adjustments]
- [Dependency updates in DAY0_BACKLOG]
```

### Timeline Conflict Escalation (Weekly/Monthly Review)

**Trigger:** Wave timing conflict between device and infra roadmaps  
**Owner:** Codex-PM-011 + miket-infra Product Manager  
**Action:**
1. Document conflict in monthly review report
2. Propose resolution options (stagger, priority shift, scope reduction)
3. Schedule joint review with miket-infra PM
4. Agree on resolution and document in both COMMUNICATION_LOGs
5. Update both roadmaps with timing adjustments

### Integration Failure Escalation (Validation Failure)

**Trigger:** Integration point validation test fails  
**Owner:** Codex-CA-001 (Chief Architect)  
**Action:**
1. Document failure in COMMUNICATION_LOG with test evidence
2. Root cause analysis (device-side vs infra-side issue)
3. If infra-side: escalate to miket-infra Chief Architect
4. If device-side: create fix task in DAY0_BACKLOG
5. Re-test and document resolution

---

## Validation Automation

### Proposed Playbooks (Wave 4)

Create automated validation playbooks to reduce manual alignment checks:

**1. `playbooks/validate-tailscale-acl-alignment.yml`**
- Fetch current Tailscale ACL from miket-infra Terraform state
- Compare device tags vs ACL `tagOwners`
- Verify SSH rules match device Tailscale SSH configuration
- Output: Alignment report with pass/fail per device

**2. `playbooks/validate-compliance-evidence.yml`**
- Check `/space/devices/<host>/compliance` file format
- Verify all required fields present (FileVault, BitLocker, EDR status)
- Compare against Entra compliance schema (from miket-infra)
- Output: Compliance evidence validation report

**3. `playbooks/validate-azure-monitor-integration.yml`**
- Send test log events from each device
- Query Azure Monitor workspace for received events
- Verify schema matches miket-infra dashboard queries
- Output: Log shipping validation report

**4. `playbooks/validate-nomachine-connectivity.yml`**
- Test NoMachine connection from each client to server
- Measure latency, throughput, session establishment time
- Verify fallback paths (Tailscale → LAN)
- Output: Remote access validation report

### CI Integration (Wave 4)

**Goal:** Automated alignment validation in CI pipeline

**Approach:**
- Weekly cron job runs validation playbooks
- Results posted to Slack/Teams Ops channel
- Failures trigger blocker escalation process
- Success metrics tracked over time for trend analysis

---

## Governance & Ownership

### Responsible

- **Codex-PM-011 (miket-infra-devices PM):** Weekly checks, monthly reviews, escalations
- **Codex-CA-001 (miket-infra-devices CA):** Integration validation, technical alignment
- **Device-specific engineers:** Domain-specific dependency tracking

### Accountable

- **Codex-PM-011:** Overall roadmap alignment and dependency management
- **Codex-CA-001:** Technical integration correctness

### Consulted

- **miket-infra Product Manager:** All roadmap changes, dependency negotiations
- **miket-infra Chief Architect:** Integration point design, technical escalations

### Informed

- **Leadership:** Via quarterly roadmap updates
- **Device team:** Via EXECUTION_TRACKER and COMMUNICATION_LOG
- **Infra team:** Via cross-posted COMMUNICATION_LOG entries (when relevant)

---

## Success Metrics

### Alignment Quality

- **Dependency hit rate:** % of miket-infra dependencies delivered on time for device consumption
- **Blocker resolution time:** Average days from blocker identification to resolution
- **Integration test pass rate:** % of validation playbooks passing

### Process Efficiency

- **Weekly check completion:** % of weeks with alignment check completed on Monday
- **Monthly review attendance:** % of months with full 2-hour deep review completed
- **Quarterly update timeliness:** % of quarters with update published within 1 week of miket-infra quarterly

### Impact on Delivery

- **Wave on-time delivery:** % of device waves completing on original schedule
- **Scope stability:** % of waves with no scope reduction due to miket-infra delays
- **Rework rate:** % of device deliverables requiring rework due to miket-infra changes

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0   | 2025-11-23 | Codex-PM-011 | Initial protocol creation |

---

## Related Documentation

- [V1_0_ROADMAP.md](./V1_0_ROADMAP.md) - miket-infra-devices roadmap
- [EXECUTION_TRACKER.md](./EXECUTION_TRACKER.md) - Agent status and deliverables
- [DAY0_BACKLOG.md](./DAY0_BACKLOG.md) - Wave 1 task backlog
- [TEAM_ROLES.md](./TEAM_ROLES.md) - Multi-persona protocol
- [DOCUMENTATION_STANDARDS.md](./DOCUMENTATION_STANDARDS.md) - Artifact standards

**miket-infra references (assumed):**
- `miket-infra/docs/product/V2_0_ROADMAP.md` - Infrastructure platform roadmap
- `miket-infra/docs/communications/COMMUNICATION_LOG.md` - Infrastructure decision log
- `miket-infra/docs/product/EXECUTION_TRACKER.md` - Infrastructure task tracker

