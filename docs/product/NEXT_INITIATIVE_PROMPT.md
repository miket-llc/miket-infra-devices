---
document_title: "Wave 1 Completion: RDP/VNC Cleanup & NoMachine Client Standardization"
author: "Codex-PM-011 (Product Manager)"
last_updated: 2025-11-23
status: Ready for Execution
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-next-initiative
---

# Wave 1 Completion Initiative: RDP/VNC Cleanup & NoMachine Client Standardization

## MANDATORY MULTI-PERSONA EXECUTION PROTOCOL

**Codex-CA-001 (Chief Architect) & Codex-PM-011 (Product Manager)** — Execute this initiative using the mandatory multi-persona protocol below.

---

## Executive Summary

**Objective:** Complete Wave 1 device onboarding by removing deprecated RDP/VNC infrastructure and standardizing NoMachine client configurations across all devices.

**Current State:**
- ✅ NoMachine servers validated (motoko, wintermute, armitage on port 4000)
- ✅ RDP/VNC architecturally retired by miket-infra (2025-11-22)
- ✅ 3 RDP playbooks deleted (configure-windows-rdp.yml, diagnose-rdp.yml, REMOTE_DESKTOP.md)
- ⚠️ 9 playbooks still contain RDP/VNC references
- ⚠️ NoMachine client not standardized across devices
- ⚠️ DEV-010, DEV-011, DEV-005 in progress but not complete

**Target State:**
- ✅ Zero RDP/VNC references in codebase (architectural alignment)
- ✅ NoMachine client installed and tested on all devices
- ✅ NoMachine connection profiles standardized (port 4000, Tailscale transport)
- ✅ Remote access documentation updated (NoMachine-only)
- ✅ Wave 1 release criteria met

**Scope:**
- **DEV-010:** Remove RDP/VNC from 9 remaining playbooks
- **DEV-011:** NoMachine E2E testing (count-zero → 3 servers)
- **DEV-005:** NoMachine client standardization playbook
- **Documentation:** Update all remote access docs to NoMachine-only

---

## Tasks from DAY0_BACKLOG.md

### DEV-010: Remove RDP/VNC Fallback Paths ⚠️ IN PROGRESS
**Owner:** Codex-NET-006 (Networking Engineer)  
**Status:** In Progress  
**Blocker:** None  

**Remaining Work:**
```
Files with RDP/VNC references (9 playbooks):
1. ansible/playbooks/motoko/recover-frozen-display.yml
2. ansible/playbooks/motoko/restore-popos-desktop.yml
3. ansible/playbooks/rollback_nomachine.yml
4. ansible/playbooks/remote_firewall.yml
5. ansible/playbooks/remote_detect.yml
6. ansible/playbooks/remote_clients.yml
7. ansible/playbooks/validate_nomachine_deployment.yml
8. ansible/playbooks/validate-roadmap-alignment.yml
9. ansible/playbooks/remote_server.yml
```

**Actions Required:**
- Remove all RDP (port 3389) and VNC (port 5900) references
- Update remote_server.yml to remove RDP/VNC server roles
- Update remote_clients.yml to remove RDP/VNC client installation
- Update remote_firewall.yml to remove RDP/VNC firewall rules
- Update remote_detect.yml to remove RDP/VNC detection logic
- Delete or update rollback_nomachine.yml (if it restores RDP/VNC)
- Update validation playbooks to test NoMachine-only

### DEV-011: Test macOS NoMachine Client ⚠️ IN PROGRESS
**Owner:** Codex-MAC-012 (macOS Engineer)  
**Status:** In Progress  
**Blocker:** NoMachine client installation on count-zero  

**Current State:**
- NoMachine.app directory exists on count-zero
- Version binary path incorrect (needs verification)
- Server connectivity pre-validated (all 3 servers reachable on port 4000)

**Actions Required:**
- Verify NoMachine client installation on count-zero
- Create connection profiles for motoko, wintermute, armitage
- Execute E2E connection tests (GUI sessions)
- Measure connection quality (latency, bandwidth, session responsiveness)
- Document test results in COMMUNICATION_LOG.md

### DEV-005: Standardize NoMachine Client Configs ✅ READY TO EXECUTE
**Owner:** Codex-UX-010 (UX/DX Designer)  
**Status:** Ready to Execute (server baseline validated)  
**Blocker:** None  

**Actions Required:**
- Create Ansible role for NoMachine client installation (macOS, Windows, Linux)
- Create standardized connection profile templates (port 4000, Tailscale hostnames)
- Create playbook to deploy client configs to all devices
- Document client installation procedure in runbooks
- Add client validation to smoke tests

---

## PHASE 1: Chief Architect as Cross-Functional Proxy

**Codex-CA-001**, you are responsible for assuming each team member's persona throughout execution. You must deeply understand and operate within each discipline's context:

### Persona Responsibilities for This Initiative

**Codex-NET-006 (Networking Engineer) - DEV-010:**
- When removing RDP/VNC references, embody this role
- Understand firewall rule syntax (UFW, firewalld, Windows Firewall)
- Understand Tailscale ACL policies and port restrictions
- Verify NoMachine port 4000 is the ONLY remote desktop port after cleanup
- Test network paths end-to-end (no RDP 3389, no VNC 5900 listening)
- **Never assume** - verify with `netstat`/`ss` that ports are closed

**Codex-MAC-012 (macOS Engineer) - DEV-011:**
- When testing NoMachine client, become this role
- Understand macOS NoMachine.app structure and binary paths
- Understand macOS connection profile storage (~/.nx/)
- Test GUI session quality (frame rate, latency, clipboard, file transfer)
- Document macOS-specific issues (SIP, permissions, firewall prompts)
- **Never assume** - actually launch NoMachine GUI and connect to all 3 servers

**Codex-UX-010 (UX/DX Designer) - DEV-005:**
- When standardizing client configs, assume this role
- Understand persona workflows (admin vs developer vs end-user)
- Design connection profiles for ease of use (save passwords, auto-connect options)
- Measure time-to-first-connection (TTFC) for new devices
- Verify every interface is user-tested (can non-technical user connect?)
- **Never assume** - test the UX from a user's perspective

**Codex-DOC-009 (DocOps) - Documentation:**
- When updating docs, become this persona
- Audit ALL remote access documentation before changes
- Merge related content into single source of truth
- Update docs/runbooks/ with NoMachine-only procedures
- Verify every artifact has proper front matter
- **Never assume** - read existing docs to avoid duplication

**Codex-PD-002 (Platform DevOps) - Testing:**
- When creating smoke tests, embody this role
- Design CI validation for NoMachine connectivity
- Create test fixtures for connection profile validation
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
   - Resolve all blockers immediately
   - Escalate to Product Manager ONLY if truly external dependency
   - Parallelize non-blocking tasks

2. **Test end-to-end before marking complete:**
   - Write and execute test procedures (unit, integration, smoke)
   - Document test methodology and results
   - Run `make lint` and `make verify-all` to validate quality
   - Include validation commands in deliverable documentation

3. **Never leave known issues unresolved:**
   - If testing reveals bugs, fix them immediately
   - If refactoring is needed, perform it before closing
   - Document all fixes in communication log

### Specific Implementation Steps

#### DEV-010: RDP/VNC Cleanup

**As Codex-NET-006:**

1. **Audit Phase:**
   ```bash
   # Find all RDP/VNC references
   grep -r "rdp\|RDP\|3389" ansible/playbooks/
   grep -r "vnc\|VNC\|5900" ansible/playbooks/
   
   # Document what needs changing in each file
   ```

2. **Cleanup Phase:**
   - Remove RDP server installation tasks from `remote_server.yml`
   - Remove VNC server installation tasks from `remote_server.yml`
   - Remove RDP client installation from `remote_clients.yml`
   - Remove VNC client installation from `remote_clients.yml`
   - Remove RDP/VNC firewall rules from `remote_firewall.yml`
   - Remove RDP/VNC detection from `remote_detect.yml`
   - Update or delete `rollback_nomachine.yml` (if it restores RDP/VNC)

3. **Verification Phase:**
   ```bash
   # Confirm no RDP/VNC references remain
   grep -r "rdp\|RDP\|3389\|vnc\|VNC\|5900" ansible/playbooks/ ansible/roles/
   
   # Expected: Only historical references in COMMUNICATION_LOG or comments
   ```

4. **Testing Phase:**
   ```bash
   # Run playbook in check mode
   ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml --check
   
   # Verify NoMachine is the ONLY remote desktop service
   ansible all -i inventory/hosts.yml -m shell -a "netstat -tulpn | grep -E '4000|3389|5900'"
   # Expected: Only port 4000 (NoMachine), no 3389 (RDP), no 5900 (VNC)
   ```

#### DEV-011: NoMachine Client E2E Testing

**As Codex-MAC-012:**

1. **Client Verification:**
   ```bash
   # SSH to count-zero
   ssh mdt@count-zero.pangolin-vega.ts.net
   
   # Find NoMachine client binary
   find /Applications/NoMachine.app -name "nxplayer" -o -name "NoMachine"
   
   # Get version
   /Applications/NoMachine.app/Contents/MacOS/nxplayer.bin --version
   # OR
   /Applications/NoMachine.app/Contents/Frameworks/bin/nxplayer --version
   ```

2. **Connection Profile Creation:**
   - Launch NoMachine GUI on count-zero
   - Create connection profiles:
     - Name: `motoko-nx`, Host: `motoko.pangolin-vega.ts.net`, Port: 4000
     - Name: `wintermute-nx`, Host: `wintermute.pangolin-vega.ts.net`, Port: 4000
     - Name: `armitage-nx`, Host: `armitage.pangolin-vega.ts.net`, Port: 4000
   - Save credentials for auto-connect (optional)

3. **E2E Connection Tests:**
   - Test motoko connection (Linux KDE Plasma desktop)
   - Test wintermute connection (Windows desktop)
   - Test armitage connection (Windows desktop)
   - For each connection, verify:
     - Connection time < 10 seconds
     - Session quality: Good or Excellent
     - Desktop appears and is responsive
     - Mouse/keyboard input works
     - Clipboard copy/paste works
     - File transfer works (drag/drop)

4. **Results Documentation:**
   ```markdown
   ## NoMachine Client Test Results - count-zero
   
   **Test Date:** 2025-11-23
   **Client:** count-zero (macOS)
   **NoMachine Version:** [version]
   
   | Server | Connection Time | Quality | Latency | Status | Issues |
   |--------|----------------|---------|---------|--------|--------|
   | motoko | [seconds] | [rating] | [ms] | PASS/FAIL | [none or list] |
   | wintermute | [seconds] | [rating] | [ms] | PASS/FAIL | [none or list] |
   | armitage | [seconds] | [rating] | [ms] | PASS/FAIL | [none or list] |
   
   **Overall:** [PASS if all 3 succeed, FAIL if any fail]
   ```

#### DEV-005: NoMachine Client Standardization

**As Codex-UX-010:**

1. **Create Client Installation Role:**
   ```
   ansible/roles/nomachine_client/
   ├── defaults/main.yml          # Default vars (version, port, etc.)
   ├── tasks/main.yml              # Installation tasks
   ├── tasks/macos.yml             # macOS-specific installation
   ├── tasks/windows.yml           # Windows-specific installation
   ├── tasks/linux.yml             # Linux-specific installation
   ├── templates/connection.nxs.j2 # Connection profile template
   └── README.md                   # Role documentation
   ```

2. **Create Connection Profile Templates:**
   - Standard profile: `{{ server_name }}.pangolin-vega.ts.net:4000`
   - Authentication: Password (stored in user's NoMachine config)
   - Quality: Adaptive (auto-adjust based on network)
   - Codec: H.264 when available

3. **Create Deployment Playbook:**
   ```yaml
   # ansible/playbooks/deploy-nomachine-clients.yml
   - name: Deploy NoMachine clients to all devices
     hosts: all
     roles:
       - nomachine_client
   ```

4. **UX Validation:**
   - TTFC (Time to First Connection) < 2 minutes for new device
   - Connection profiles pre-configured (user just clicks)
   - Clear error messages if connection fails
   - Fallback instructions if MagicDNS fails (use IP addresses)

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
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-nomachine-clients.yml --limit count-zero
   
   # Step 2: Validate dev deployment
   ssh mdt@count-zero.pangolin-vega.ts.net "test -d /Applications/NoMachine.app && echo 'PASS' || echo 'FAIL'"
   
   # Step 3: Deploy to staging (wintermute, armitage)
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-nomachine-clients.yml --limit windows_workstations
   
   # Step 4: Validate staging deployment
   # [Validation commands]
   
   # Step 5: Deploy to prod (all devices)
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-nomachine-clients.yml
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

**Current Version:** v1.6.1 (from miket-infra, device repo likely matching or close)

**Review Changes:**
- RDP/VNC removal (architectural cleanup)
- NoMachine client standardization (new feature)
- Wave 1 completion (milestone)

**Version Increment Decision:**
- **Patch (v1.6.2):** If only cleanup and bug fixes
- **Minor (v1.7.0):** If NoMachine client standardization is substantial new feature
- **Major (v2.0.0):** If this represents fundamental architecture shift (unlikely)

**Recommended:** v1.7.0 (NoMachine client standardization = new feature)

**Update Locations:**
1. `README.md` - Architecture Version field
2. `docs/product/EXECUTION_TRACKER.md` - Version header
3. `docs/product/V1_0_ROADMAP.md` - Wave 1 completion status
4. Commit message: `release: bump version from v1.6.1 to v1.7.0 with Wave 1 completion (NoMachine standardization, RDP/VNC removal)`

### Update Product Roadmap

**Tasks:**
1. Mark Wave 1 as "Complete" in `docs/product/V1_0_ROADMAP.md`
2. Add completed tasks to "Completed" section:
   - DEV-010: RDP/VNC removal from all playbooks
   - DEV-011: NoMachine E2E testing validated
   - DEV-005: NoMachine client standardization deployed
3. Update Wave 2 readiness status
4. Document new dependencies discovered (if any)
5. Update EXECUTION_TRACKER with Wave 2 task assignments

### Recommend Specific Next Steps

**In follow-up message, provide:**

1. **What was delivered and its impact:**
   - RDP/VNC fully removed (9 playbooks cleaned)
   - NoMachine client standardized across all devices
   - Remote access UX validated (E2E tests passed)
   - Wave 1 completion unblocks Wave 2

2. **Which personas contributed and their next workstreams:**
   - Codex-NET-006: Ready for Wave 2 Cloudflare Access mapping
   - Codex-MAC-012: Ready for macOS onboarding automation
   - Codex-UX-010: Ready for remote access UX instrumentation

3. **Top 3 technical blockers/opportunities:**
   - MagicDNS fix still needed (coordinate with miket-infra)
   - Entra compliance feed schema (Wave 2 dependency)
   - Device persona matrix (Wave 2 Cloudflare Access)

4. **Recommended sequencing for Wave 2:**
   - Start DEV-006 (compliance attestations) immediately
   - Request device persona matrix from miket-infra
   - Prepare Azure Monitor integration (DEV-008)

5. **Process improvements:**
   - [Any lessons learned from Wave 1]
   - [Documentation or testing gaps discovered]

---

## PROTOCOL ENFORCEMENT CHECKPOINTS

**Every PR or change must pass these gates before merging:**

- [ ] **Governance:** All Markdown filed in correct taxonomy with complete front matter; no standalone files in repo root
- [ ] **Consolidation:** No duplicate content; all related docs merged into initiative packages
- [ ] **Completion:** Task 100% implemented; all blockers resolved; no partial/stubbed work
- [ ] **Testing:** End-to-end tests documented and passed; quality gates (`make lint`) green
- [ ] **Communication:** Communication log entry added within 24 hours; EXECUTION_TRACKER updated with links
- [ ] **Version Control:** (Product Manager) Version number incremented; roadmap updated; next steps documented
- [ ] **Deployment:** (If authorized) Deployed successfully; troubleshooting completed; rollback tested

**No exceptions. No shortcuts.**

---

## SUCCESS CRITERIA (Wave 1 Release Criteria)

**From V1_0_ROADMAP.md:**

- [x] NoMachine servers operational and validated (completed 2025-11-23)
- [ ] Zero RDP/VNC references in codebase
- [ ] NoMachine client installed on all devices (count-zero, wintermute, armitage)
- [ ] E2E connection tests passed (all 3 servers from all clients)
- [ ] Remote access documentation updated (NoMachine-only)
- [ ] COMMUNICATION_LOG entry with evidence and test results
- [ ] Version incremented to v1.7.0
- [ ] Wave 1 marked complete in roadmap

---

## EXECUTION START

**Codex-CA-001 (Chief Architect)**, begin execution:

1. Switch to **Codex-NET-006** persona
2. Execute DEV-010 (RDP/VNC cleanup in 9 playbooks)
3. Test and validate (no RDP/VNC ports listening)
4. Update COMMUNICATION_LOG.md

5. Switch to **Codex-MAC-012** persona
6. Execute DEV-011 (NoMachine E2E testing from count-zero)
7. Document test results
8. Update COMMUNICATION_LOG.md

9. Switch to **Codex-UX-010** persona
10. Execute DEV-005 (NoMachine client standardization)
11. Create role, templates, playbook
12. Update COMMUNICATION_LOG.md

13. Switch to **Codex-DOC-009** persona
14. Audit and update all remote access documentation
15. Consolidate into single source of truth
16. Update COMMUNICATION_LOG.md

17. Switch to **Codex-PD-002** persona
18. Create smoke tests for NoMachine connectivity
19. Validate tests pass
20. Update COMMUNICATION_LOG.md

**Codex-PM-011 (Product Manager)**, after Chief Architect completion:

1. Review all deliverables against checkpoints
2. Increment version to v1.7.0
3. Update V1_0_ROADMAP.md (Wave 1 complete)
4. Provide next steps recommendation

**DO NOT STOP UNTIL ALL SUCCESS CRITERIA ARE MET.**

---

## End of Initiative Prompt

