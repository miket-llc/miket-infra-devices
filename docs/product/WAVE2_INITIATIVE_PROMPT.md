---
document_title: "Wave 2: Cloudflare Access Mapping & Remote Access UX Enhancement"
author: "Codex-PM-011 (Product Manager)"
last_updated: 2025-11-23
status: Ready for Execution
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-wave1-completion
---

# Wave 2 Initiative: Cloudflare Access Mapping & Remote Access UX Enhancement

## MANDATORY MULTI-PERSONA EXECUTION PROTOCOL

**Codex-CA-001 (Chief Architect) & Codex-PM-011 (Product Manager)** — Execute this initiative using the mandatory multi-persona protocol below.

---

## Executive Summary

**Objective:** Complete Wave 2 remote access UX enhancement by mapping device personas to Cloudflare Access policies, implementing certificate enrollment, and establishing Tailscale ACL drift checks.

**Current State:**
- ✅ Wave 1 complete (v1.7.0): NoMachine standardized, RDP/VNC removed
- ✅ NoMachine servers operational (motoko, wintermute, armitage on port 4000)
- ✅ NoMachine clients tested and validated (count-zero → all servers PASS)
- ✅ Tailscale ACL alignment verified (device tags match ACL tagOwners)
- ⚠️ Cloudflare Access device persona matrix pending from miket-infra
- ⚠️ Certificate enrollment not configured
- ⚠️ Tailscale ACL drift checks not automated

**Target State:**
- ✅ Device personas mapped to Cloudflare Access groups
- ✅ Remote app policies configured (NoMachine, SSH)
- ✅ Certificate enrollment automated for all devices
- ✅ Tailscale ACL drift checks automated (weekly validation)
- ✅ Wave 2 release criteria met

**Scope:**
- **DEV-007:** Map Cloudflare Access + device personas for remote app access
- **DEV-012:** Coordinate with miket-infra for device persona matrix
- **DEV-013:** Implement certificate enrollment automation
- **DEV-014:** Create Tailscale ACL drift check automation
- **Documentation:** Update remote access runbooks with Cloudflare Access procedures

---

## Tasks from DAY0_BACKLOG.md

### DEV-007: Map Cloudflare Access + Device Personas ⚠️ BLOCKED
**Owner:** Codex-SEC-004 (Security/IAM)  
**Status:** Blocked (waiting for miket-infra device persona matrix)  
**Blocker:** miket-infra Cloudflare Access device persona matrix (expected Jan 2026)

**Remaining Work:**
```
Dependencies:
1. Request device persona matrix from miket-infra
2. Map device personas to Cloudflare Access groups
3. Configure remote app policies (NoMachine, SSH)
4. Test access from each device persona
5. Document mapping in runbooks
```

**Actions Required:**
- Request device persona matrix from miket-infra (coordinate with DEV-012)
- Map device personas (workstation, server, mobile) to Cloudflare Access groups
- Configure access policies for remote apps (NoMachine, SSH, admin tools)
- Create validation playbook to test access from each persona
- Document Cloudflare Access procedures in runbooks

### DEV-012: Coordinate with miket-infra for Device Persona Matrix ⚠️ IN PROGRESS
**Owner:** Codex-PM-011 (Product Manager)  
**Status:** In Progress  
**Blocker:** None (coordination task)

**Actions Required:**
- Request device persona matrix from miket-infra
- Request Cloudflare Access policy documentation
- Coordinate certificate enrollment requirements
- Request Wave 2 deliverables timeline
- Document coordination results in COMMUNICATION_LOG

### DEV-013: Implement Certificate Enrollment Automation 🔜 PLANNED
**Owner:** Codex-SEC-004 (Security/IAM)  
**Status:** Planned  
**Blocker:** Cloudflare Access device persona matrix (DEV-007)

**Actions Required:**
- Create Ansible role for certificate enrollment (Cloudflare WARP/Gateway)
- Configure certificate enrollment for all device personas
- Test certificate enrollment on each platform (macOS, Windows, Linux)
- Create validation playbook for certificate status
- Document enrollment procedures in runbooks

### DEV-014: Create Tailscale ACL Drift Check Automation 🔜 PLANNED
**Owner:** Codex-NET-006 (Networking Engineer)  
**Status:** Planned  
**Blocker:** None

**Actions Required:**
- Create playbook to fetch miket-infra Tailscale ACL state
- Compare device tags vs ACL tagOwners
- Validate SSH rules match device configurations
- Validate NoMachine port rules (4000) match device inventory
- Create weekly validation job (integrate with CI)
- Document drift check procedures

---

## PHASE 1: Chief Architect as Cross-Functional Proxy

**Codex-CA-001**, you are responsible for assuming each team member's persona throughout execution. You must deeply understand and operate within each discipline's context:

### Persona Responsibilities for This Initiative

**Codex-SEC-004 (Security/IAM) - DEV-007, DEV-013:**
- When mapping Cloudflare Access, embody this role
- Understand Cloudflare Access policy syntax and group management
- Understand device persona taxonomy (workstation, server, mobile)
- Map personas to Cloudflare Access groups correctly
- Test access policies end-to-end (can each persona access intended apps?)
- **Never assume** - verify access policies work from actual devices

**Codex-PM-011 (Product Manager) - DEV-012:**
- When coordinating with miket-infra, become this role
- Request device persona matrix with clear requirements
- Document coordination results and timelines
- Escalate blockers promptly
- **Never assume** - get explicit confirmation from miket-infra team

**Codex-NET-006 (Networking Engineer) - DEV-014:**
- When creating ACL drift checks, assume this role
- Understand Tailscale ACL JSON structure
- Understand device tag taxonomy and ACL tagOwners mapping
- Verify SSH and NoMachine port rules match device inventory
- Create idempotent validation playbooks
- **Never assume** - test drift detection with actual ACL changes

**Codex-DOC-009 (DocOps) - Documentation:**
- When updating docs, become this persona
- Audit ALL remote access documentation before changes
- Merge related content into single source of truth
- Update docs/runbooks/ with Cloudflare Access procedures
- Verify every artifact has proper front matter
- **Never assume** - read existing docs to avoid duplication

**Codex-PD-002 (Platform DevOps) - Testing:**
- When creating validation playbooks, embody this role
- Design CI validation for Cloudflare Access policies
- Create test fixtures for certificate enrollment validation
- Verify tests are idempotent and can run in check mode
- **Never assume** - run tests locally before committing

### Protocol Enforcement

- **Never assume capability or correctness. Verify everything.**
- Reference `docs/product/TEAM_ROLES.md` and `docs/product/DAY0_BACKLOG.md` for role responsibilities
- When switching personas, re-read relevant docs and recent changes
- **If a persona's task is implicit, perform it anyway** (e.g., always update docs even if not explicitly stated)

---

## PHASE 2: Governance & Documentation Discipline

### Chief Architect Responsibilities

Follow all protocols in `docs/product/DOCUMENTATION_STANDARDS.md`:

#### Mandatory Front Matter on Every Artifact
```yaml
---
document_title: "<title>"
author: "<persona>"
last_updated: 2025-11-23
status: Draft|In Review|Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#YYYY-MM-DD-<anchor>
---
```

#### Correct Directory Taxonomy
- **Playbooks:** `ansible/playbooks/` (no standalone files)
- **Roles:** `ansible/roles/<role-name>/` (defaults, tasks, templates, handlers)
- **Runbooks:** `docs/runbooks/<procedure>.md` (operational procedures)
- **Initiatives:** `docs/initiatives/<initiative-name>/` (if multi-file initiative)
- **Communication Log:** `docs/communications/COMMUNICATION_LOG.md` (dated entries with anchors)

#### ZERO Ephemeral Markdown
- **NO** standalone .md files in repo root
- **NO** ad-hoc documentation outside taxonomy
- **NO** duplicate content (audit before creating new files)

#### Consolidation Rules
1. Audit existing docs before creating new files
2. Merge related content into single source of truth
3. Link instead of duplicate
4. Use initiative packages for multi-file deliverables

#### Communication Log Updates (Within 24 Hours)
```markdown
## YYYY-MM-DD – Initiative Name {#YYYY-MM-DD-anchor}

### Context
[Why this work was done]

### Actions Taken
[What was changed]

### Outcomes
[Results, test evidence, links to artifacts]

### Next Steps
[Follow-up work]

---
```

#### EXECUTION_TRACKER Updates (Immediate)
- Update `docs/product/EXECUTION_TRACKER.md` when delivering output
- Include link to PR/commit/runbook in "Latest Output" column
- Move tasks to "Done" ONLY after documentation filed with complete front matter

---

## PHASE 3: Complete Task Implementation

### Task Execution Requirements

**Chief Architect must:**

1. **Fully implement all assigned tasks** from `docs/product/DAY0_BACKLOG.md`:
   - Do NOT stub, defer, or partially implement
   - Resolve all blockers immediately (or escalate to Product Manager)
   - Escalate to Product Manager ONLY if truly external dependency
   - Parallelize non-blocking tasks

2. **Test end-to-end before marking complete:**
   - Write and execute test procedures (unit, integration, smoke)
   - Document test methodology and results
   - Run validation playbooks to verify quality
   - Include validation commands in deliverable documentation

3. **Never leave known issues unresolved:**
   - If testing reveals bugs, fix them immediately
   - If refactoring is needed, perform it before closing
   - Document all fixes in communication log

### Specific Implementation Steps

#### DEV-012: Coordinate with miket-infra (First Priority)

**As Codex-PM-011:**

1. **Request Device Persona Matrix:**
   - Contact miket-infra Product Manager
   - Request Cloudflare Access device persona mapping document
   - Request timeline for Wave 2 deliverables
   - Document request in COMMUNICATION_LOG

2. **Request Cloudflare Access Policy Documentation:**
   - Request current Cloudflare Access policy configuration
   - Request policy syntax and group management procedures
   - Request certificate enrollment requirements
   - Document responses in COMMUNICATION_LOG

3. **Coordinate Certificate Enrollment:**
   - Request Cloudflare WARP/Gateway certificate enrollment procedures
   - Request certificate authority (CA) details
   - Request enrollment automation requirements
   - Document coordination results

#### DEV-007: Map Cloudflare Access + Device Personas (After DEV-012)

**As Codex-SEC-004:**

1. **Map Device Personas:**
   - Review miket-infra device persona matrix
   - Map device personas to Cloudflare Access groups:
     - `workstation` → Cloudflare Access group (TBD)
     - `server` → Cloudflare Access group (TBD)
     - `mobile` → Cloudflare Access group (TBD)
   - Document mapping in `docs/runbooks/cloudflare-access-mapping.md`

2. **Configure Remote App Policies:**
   - Create access policies for NoMachine (port 4000)
   - Create access policies for SSH (port 22)
   - Create access policies for admin tools (if applicable)
   - Test policies from each device persona

3. **Create Validation Playbook:**
   - Create `ansible/playbooks/validate-cloudflare-access.yml`
   - Test access from each device persona
   - Verify policies match device inventory
   - Document test results

#### DEV-013: Certificate Enrollment Automation (After DEV-007)

**As Codex-SEC-004:**

1. **Create Certificate Enrollment Role:**
   ```
   ansible/roles/certificate_enrollment/
   ├── defaults/main.yml          # Default vars (CA, enrollment URL, etc.)
   ├── tasks/main.yml              # Enrollment tasks
   ├── tasks/macos.yml             # macOS-specific enrollment
   ├── tasks/windows.yml           # Windows-specific enrollment
   ├── tasks/linux.yml             # Linux-specific enrollment
   └── README.md                   # Role documentation
   ```

2. **Create Enrollment Playbook:**
   ```yaml
   # ansible/playbooks/enroll-certificates.yml
   - name: Enroll certificates for all devices
     hosts: all
     roles:
       - certificate_enrollment
   ```

3. **Create Validation Playbook:**
   - Verify certificates are enrolled
   - Verify certificates are valid and not expired
   - Test certificate-based access to Cloudflare Access apps

#### DEV-014: Tailscale ACL Drift Check Automation

**As Codex-NET-006:**

1. **Create ACL Fetch Playbook:**
   - Fetch miket-infra Tailscale ACL state (via API or Terraform state)
   - Parse ACL JSON structure
   - Extract device tag mappings and port rules

2. **Create Drift Detection Playbook:**
   ```yaml
   # ansible/playbooks/validate-tailscale-acl-drift.yml
   - name: Validate Tailscale ACL alignment
     hosts: localhost
     tasks:
       - name: Fetch miket-infra ACL state
         # [Fetch ACL from miket-infra]
       
       - name: Compare device tags vs ACL tagOwners
         # [Compare device inventory tags with ACL tagOwners]
       
       - name: Validate SSH rules
         # [Verify SSH rules match device configurations]
       
       - name: Validate NoMachine port rules
         # [Verify port 4000 rules match device inventory]
   ```

3. **Create Weekly Validation Job:**
   - Integrate drift check into CI pipeline
   - Run weekly (every Monday)
   - Alert on drift detection
   - Document drift check procedures

---

## PHASE 4: Deployment & Troubleshooting

**Chief Architect must:**

### Deployment Authorization

**Deploy ONLY when explicitly instructed** by this chat or Product Manager.

### When Deployment IS Authorized

1. **Execute to appropriate environment:**
   - Dev: Test on count-zero first
   - Staging: Deploy to wintermute/armitage
   - Prod: Deploy to all devices after validation

2. **Sequence:**
   ```bash
   # Step 1: Deploy to dev (count-zero)
   ansible-playbook -i inventory/hosts.yml playbooks/enroll-certificates.yml --limit count-zero
   
   # Step 2: Validate dev deployment
   ansible-playbook -i inventory/hosts.yml playbooks/validate-cloudflare-access.yml --limit count-zero
   
   # Step 3: Deploy to staging (wintermute, armitage)
   ansible-playbook -i inventory/hosts.yml playbooks/enroll-certificates.yml --limit windows_workstations
   
   # Step 4: Validate staging deployment
   # [Validation commands]
   
   # Step 5: Deploy to prod (all devices)
   ansible-playbook -i inventory/hosts.yml playbooks/enroll-certificates.yml
   ```

3. **DO NOT STOP until it's perfect:**
   - Test every step post-deployment
   - Verify health checks and observability
   - If deployment fails, troubleshoot root cause immediately
   - Fix the failure (code, config, environment)
   - Re-deploy and re-validate end-to-end
   - **Do NOT proceed** until current deployment is 100% successful

4. **Document all deployment steps:**
   ```markdown
   ## Deployment Log - YYYY-MM-DD HH:MM
   
   **Environment:** [dev/staging/prod]
   **Playbook:** [playbook name]
   **Target:** [hosts]
   **Result:** [SUCCESS/FAILED]
   
   **Steps:**
   1. [Step description] - [PASS/FAIL]
   2. [Step description] - [PASS/FAIL]
   
   **Issues Encountered:**
   - [Issue description]
   - Root cause: [analysis]
   - Fix applied: [solution]
   
   **Validation:**
   - [Test 1] - [PASS/FAIL]
   - [Test 2] - [PASS/FAIL]
   
   **Rollback:** [Not needed / Executed successfully]
   ```

---

## PHASE 5: Product Manager Review & Version Management

**Codex-PM-011 (Product Manager)**, at the conclusion of Chief Architect execution:

### Review All Changes and Deliverables

**Checklist:**
- [ ] All output filed per documentation standards
- [ ] Communication log entries exist and are accurate
- [ ] EXECUTION_TRACKER updated with links to all artifacts
- [ ] No ephemeral files outside library structure
- [ ] End-to-end tests documented and passed

### Evaluate and Increment Version Numbers

**Current Version:** v1.7.0 (Wave 1 completion)

**Review Changes:**
- Cloudflare Access mapping (new feature)
- Certificate enrollment automation (new feature)
- Tailscale ACL drift checks (new feature)
- Wave 2 completion (milestone)

**Version Increment Decision:**
- **Patch (v1.7.1):** If only bug fixes and minor updates
- **Minor (v1.8.0):** If Cloudflare Access mapping is substantial new feature
- **Major (v2.0.0):** If this represents fundamental architecture shift (unlikely)

**Recommended:** v1.8.0 (Cloudflare Access mapping = new feature)

**Update Locations:**
1. `README.md` - Architecture Version field
2. `docs/product/EXECUTION_TRACKER.md` - Version header
3. `docs/product/V1_0_ROADMAP.md` - Wave 2 completion status
4. Commit message: `release: bump version from v1.7.0 to v1.8.0 with Wave 2 completion (Cloudflare Access mapping, certificate enrollment, ACL drift checks)`

### Update Product Roadmap

**Tasks:**
1. Mark Wave 2 as "Complete" in `docs/product/V1_0_ROADMAP.md`
2. Add completed tasks to "Completed" section:
   - DEV-007: Cloudflare Access + device persona mapping
   - DEV-012: miket-infra coordination complete
   - DEV-013: Certificate enrollment automation deployed
   - DEV-014: Tailscale ACL drift checks automated
3. Update Wave 3 readiness status
4. Document new dependencies discovered (if any)
5. Update EXECUTION_TRACKER with Wave 3 task assignments

### Recommend Specific Next Steps

**In follow-up message, provide:**

1. **What was delivered and its impact:**
   - Cloudflare Access device persona mapping complete
   - Certificate enrollment automated across all devices
   - Tailscale ACL drift checks operational
   - Wave 2 completion unblocks Wave 3

2. **Which personas contributed and their next workstreams:**
   - Codex-SEC-004: Ready for Wave 3 compliance attestations
   - Codex-NET-006: Ready for Wave 3 observability integration
   - Codex-PM-011: Ready for Wave 3 planning

3. **Top 3 technical blockers/opportunities:**
   - Azure Monitor workspace IDs (Wave 3 dependency)
   - Entra compliance feed schema (Wave 3 dependency)
   - Device telemetry requirements (Wave 3 dependency)

4. **Recommended sequencing for Wave 3:**
   - Start DEV-006 (compliance attestations) immediately
   - Request Azure Monitor workspace IDs from miket-infra
   - Prepare observability integration (DEV-008)

5. **Process improvements:**
   - [Any lessons learned from Wave 2]
   - [Documentation or testing gaps discovered]

---

## PROTOCOL ENFORCEMENT CHECKPOINTS

**Every PR or change must pass these gates before merging:**

- [ ] **Governance:** All Markdown filed in correct taxonomy with complete front matter; no standalone files in repo root
- [ ] **Consolidation:** No duplicate content; all related docs merged into initiative packages
- [ ] **Completion:** Task 100% implemented; all blockers resolved; no partial/stubbed work
- [ ] **Testing:** End-to-end tests documented and passed; quality gates green
- [ ] **Communication:** Communication log entry added within 24 hours; EXECUTION_TRACKER updated with links
- [ ] **Version Control:** (Product Manager) Version number incremented; roadmap updated; next steps documented
- [ ] **Deployment:** (If authorized) Deployed successfully; troubleshooting completed; rollback tested

**No exceptions. No shortcuts.**

---

## SUCCESS CRITERIA (Wave 2 Release Criteria)

**From V1_0_ROADMAP.md:**

- [ ] Device personas mapped to Cloudflare Access groups
- [ ] Remote app policies configured (NoMachine, SSH)
- [ ] Certificate enrollment automated for all devices
- [ ] Tailscale ACL drift checks automated (weekly validation)
- [ ] Cloudflare Access validation playbook created and passing
- [ ] Remote access runbooks updated with Cloudflare Access procedures
- [ ] COMMUNICATION_LOG entry with evidence and test results
- [ ] Version incremented to v1.8.0
- [ ] Wave 2 marked complete in roadmap

---

## EXECUTION START

**Codex-CA-001 (Chief Architect)**, begin execution:

1. Switch to **Codex-PM-011** persona
2. Execute DEV-012 (Coordinate with miket-infra for device persona matrix)
3. Document coordination results
4. Update COMMUNICATION_LOG.md

5. Switch to **Codex-SEC-004** persona
6. Execute DEV-007 (Map Cloudflare Access + device personas)
7. Create validation playbook
8. Update COMMUNICATION_LOG.md

9. Switch to **Codex-SEC-004** persona
10. Execute DEV-013 (Certificate enrollment automation)
11. Create role, playbook, validation
12. Update COMMUNICATION_LOG.md

13. Switch to **Codex-NET-006** persona
14. Execute DEV-014 (Tailscale ACL drift checks)
15. Create drift detection playbook
16. Update COMMUNICATION_LOG.md

17. Switch to **Codex-DOC-009** persona
18. Audit and update all remote access documentation
19. Consolidate into single source of truth
20. Update COMMUNICATION_LOG.md

**Codex-PM-011 (Product Manager)**, after Chief Architect completion:

1. Review all deliverables against checkpoints
2. Increment version to v1.8.0
3. Update V1_0_ROADMAP.md (Wave 2 complete)
4. Provide next steps recommendation

**DO NOT STOP UNTIL ALL SUCCESS CRITERIA ARE MET.**

---

## End of Initiative Prompt

