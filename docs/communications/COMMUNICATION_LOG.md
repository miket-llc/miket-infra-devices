# Device Infrastructure Communication Log

Chronological log of all significant actions, decisions, and outcomes for the miket-infra-devices repository.

---

## 2025-01-XX – USB 3.0 20TB Drive Integration {#2025-01-usb-storage}

### Context
CEO connected 20TB USB 3.0 hard drive to motoko in preparation for enterprise-class cloud file storage. Drive has two APFS partitions:
- Time Machine partition (for count-zero backups)
- "space" partition (for file cache storage)

### Requirements
- Maintain Time Machine partition for count-zero backups (APFS)
- Configure space partition for Linux file cache (ext4)
- Think ahead about potential issues and user experience
- Focus on working hardware/configuration, not documentation
- No additional ephemeral .md files

### Architecture Decisions

**APFS Support Strategy:**
- **Time Machine partition**: Keep APFS, use read-only apfs-fuse driver
  - Reason: Maintains compatibility with macOS Time Machine
  - Read-only access prevents accidental corruption
  - Manual mount via helper script (noauto in fstab)
- **Space partition**: Reformat to ext4
  - Reason: Optimal Linux performance and reliability
  - Native filesystem support, no FUSE overhead
  - Better for large file operations

**Mount Configuration:**
- Time Machine: `/mnt/usb-timemachine` (read-only, manual mount)
- Space: `/mnt/usb-space` (read-write, auto-mount on boot)
- File cache structure: `cache/`, `files/`, `temp/` directories

### Implementation

**Codex-DCA-001 (Chief Device Architect):**
- ✅ Created comprehensive Ansible role `usb-storage` for storage management
- ✅ Designed auto-detection of partitions by label
- ✅ Configured APFS read-only support via apfs-fuse
- ✅ Implemented ext4 reformatting with safety checks
- ✅ Created persistent mount configuration via fstab
- ✅ Set proper permissions and ownership
- ✅ Created file cache directory structure
- ✅ Updated motoko config.yml with new storage locations

**Codex-DEVOPS-004 (DevOps Engineer):**
- ✅ Created Ansible playbook `configure-usb-storage.yml` for motoko self-management
- ✅ Implemented partition detection logic
- ✅ Built APFS driver installation automation
- ✅ Created mount helper script for Time Machine partition
- ✅ Added detection script for pre-deployment verification

**Codex-INFRA-003 (Infrastructure Lead):**
- ✅ Validated APFS compatibility research (apfs-fuse for read-only)
- ✅ Designed mount point structure and permissions
- ✅ Configured fstab entries for persistence
- ✅ Created helper scripts for manual Time Machine mounting

### Technical Details

**APFS Driver:**
- Uses `apfs-fuse` (open-source, read-only)
- Builds from source on first run
- Installs to `/usr/local/bin/apfs-fuse`
- Mount command: `apfs-fuse /dev/sdX1 /mnt/usb-timemachine -o allow_other,ro`

**Space Partition:**
- Auto-detected by label "space"
- Reformatted to ext4 if not already ext4
- Mounted at `/mnt/usb-space` with noatime option
- Ownership: mdt:mdt, mode 0755

**Safety Features:**
- Backup fstab before modification
- Optional data backup before reformatting (configurable)
- Idempotent operations (safe to re-run)
- Validation checks before destructive operations

### Usage

**Detection:**
```bash
~/miket-infra-devices/scripts/detect-usb-drive.sh
```

**Configuration:**
```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/configure-usb-storage.yml \
  --limit motoko \
  --connection=local
```

**Manual Time Machine Mount:**
```bash
sudo mount-timemachine.sh
```

### Outcomes

**Deliverables:**
- ✅ Ansible role: `ansible/roles/usb-storage/`
- ✅ Playbook: `ansible/playbooks/motoko/configure-usb-storage.yml`
- ✅ Detection script: `scripts/detect-usb-drive.sh`
- ✅ Mount helper: `/usr/local/bin/mount-timemachine.sh` (created by playbook)
- ✅ Updated config: `devices/motoko/config.yml`

**Next Steps:**
- Test Time Machine backup connectivity from count-zero
- Verify file cache performance
- Monitor APFS driver stability

### Lessons Learned
- APFS on Linux requires third-party drivers (no native kernel support)
- Read-only access is safer for Time Machine partitions
- ext4 is optimal for Linux file cache operations
- Auto-detection by label is more reliable than device names
- Helper scripts improve UX for manual operations

---

## 2025-11-13 – macOS Best Practices: Tailscale MagicDNS Automation {#2025-11-13-macos-automation}

### Context
CEO identified that count-zero could not connect to Windows machines via RDP due to MagicDNS not being configured. Error 0x104 "PC can't be found" indicated DNS resolution failure.

### Root Cause Analysis
**Problem:** Homebrew Tailscale installation doesn't automatically configure macOS DNS resolvers
- `tailscale up --accept-dns` enables MagicDNS at Tailscale level
- But macOS still queries local DNS (192.168.1.1) instead of Tailscale DNS
- Requires manual /etc/resolver configuration

**Why This Happens:**
- Tailscale GUI app: Automatically configures system DNS
- Homebrew install: Doesn't touch system DNS configuration
- Result: MagicDNS "enabled" but not actually used by macOS

### Best Practices Implementation

**Codex-DEVOPS-004 (DevOps Engineer):**
- ✅ Created `scripts/bootstrap-macos.sh` - Comprehensive bootstrap script
  - Installs Tailscale via Homebrew
  - Configures `tailscale up --accept-dns --ssh`
  - Auto-detects tailnet domain from Tailscale JSON
  - Creates `/etc/resolver/pangolin-vega.ts.net` file
  - Flushes DNS cache
  - Validates DNS resolution
- ✅ Created Ansible role `tailscale_macos` for ongoing management
  - Ensures /etc/resolver file exists (idempotent)
  - Validates Tailscale configuration
  - Detects and reports drift
- ✅ Created playbook `setup-macos-tailscale.yml` for post-bootstrap management

**Codex-INFRA-003 (Infrastructure Lead):**
- ✅ Validated RDP port accessibility from count-zero (ports 3389 open on both Windows machines)
- ✅ Identified MagicDNS not configured (DNS queries going to 192.168.1.1, not Tailscale)
- ✅ Documented Microsoft Remote Desktop "Local Network Access" requirement (macOS Ventura+)
- ✅ Provided workaround: Use Tailscale IPs directly (100.89.63.123, 100.72.64.90)

**Codex-DOC-005 (Documentation Architect):**
- ✅ Created `docs/runbooks/macos-tailscale-setup.md` - Comprehensive best practices
  - Two-stage setup (bootstrap + Ansible)
  - What can vs cannot be automated
  - Credentials requirements
  - Troubleshooting guide
- ✅ Updated README.md with macOS setup instructions
- ✅ Documented separation of concerns (miket-infra vs miket-infra-devices)

### Architecture Decision: Bootstrap + Ansible Pattern

**Bootstrap (Manual, Run Once):**
- Handles interactive requirements (Tailscale auth, sudo password)
- Installs dependencies (Homebrew, Tailscale)
- Performs initial configuration
- User must be present

**Ansible (Automated, Ongoing):**
- Configuration management and drift detection
- Idempotent reconciliation
- No user interaction required
- Fully automated with vault passwords

**Why This Pattern:**
- Tailscale authentication cannot be scripted (requires browser SSO)
- Initial sudo setup requires interactive password
- Ongoing management can be fully automated
- Follows industry best practices (Puppet, Chef, Salt all use this pattern)

### Outcomes

**Immediate Fix for count-zero:**
1. Run: `sudo tailscale up --accept-dns --ssh`
2. Create resolver: `sudo bash -c "echo 'nameserver 100.100.100.100' > /etc/resolver/pangolin-vega.ts.net"`
3. Flush cache: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`
4. Verify: `ping wintermute.pangolin-vega.ts.net`

**Long-term Solution:**
- New macOS devices run `bootstrap-macos.sh` once
- Ansible manages ongoing configuration
- /etc/resolver persistence via Ansible role
- Documented in runbooks

**Limitations Documented:**
- Tailscale GUI app vs Homebrew differences
- What requires manual action vs automation
- macOS-specific security requirements (Local Network Access)

### Lessons Learned
- Test actual application connectivity, not just port accessibility
- macOS DNS resolution doesn't use /etc/resolv.conf
- Homebrew packages don't modify system configuration like GUI apps
- Some security features (Local Network Access) cannot be automated without MDM
- Document what CAN'T be automated as clearly as what can

---

## 2025-11-13 – IaC/CaC Compliance: RDP Configuration Refactoring {#2025-11-13-rdp-refactoring}

### Context
CEO identified that RDP configuration violated IaC/CaC principles with multiple redundant playbooks using imperative shell commands instead of declarative Ansible modules.

### Problem Analysis
- **3 redundant playbooks** creating RDP firewall rules (enable-rdp-simple.yml, deploy-armitage-rdp.yml, configure-windows-rdp.yml)
- **Imperative shell commands** using `New-NetFirewallRule` instead of Ansible modules
- **Contradictory logic** in remote_server_windows_rdp role (tried to enable default rules that don't exist, removed custom rules it should create)
- **Not idempotent** - firewall rules recreated on every run

### Architecture Decision: Defense in Depth
Implemented two-layer security model:
1. **Network Layer (miket-infra):** Tailscale ACL controls routing and access policy
2. **Device Layer (miket-infra-devices):** Host firewalls restrict RDP to Tailscale subnet only (100.64.0.0/10)

### Actions Taken

**Codex-QA-002 (Quality Assurance Lead):**
- ✅ Deleted `enable-rdp-simple.yml` (redundant, imperative)
- ✅ Deleted `deploy-armitage-rdp.yml` (redundant, imperative)
- ✅ Kept `configure-windows-rdp.yml` as declarative wrapper calling the role
- ✅ Verified no broken references after deletion

**Codex-DEVOPS-004 (DevOps Engineer):**
- ✅ Refactored `remote_server_windows_rdp/tasks/main.yml` to use idempotent PowerShell
- ✅ Replaced imperative commands with declarative state checking
- ✅ Added GPU validation to `windows-vllm-deploy/tasks/main.yml` (fails fast if GPU not configured)
- ✅ Tested idempotency - second run shows no firewall changes (only gpupdate)
- ✅ Deployed to both wintermute and armitage successfully

**Codex-INFRA-003 (Infrastructure Lead):**
- ✅ Verified RDP ports accessible from count-zero (nc test: ports 3389 open)
- ✅ Verified Tailscale connectivity (count-zero sees both Windows machines)
- ✅ Identified count-zero needs MagicDNS enabled and Microsoft Remote Desktop app
- ✅ Documented connection requirements

**Codex-DOC-005 (Documentation Architect):**
- ✅ Created `ansible/roles/remote_server_windows_rdp/README.md` documenting defense-in-depth model
- ✅ Updated `docs/architecture/tailnet.md` with two-layer security explanation
- ✅ Updated `docs/product/STATUS.md` with IaC/CaC compliance status
- ✅ Removed temporary documentation files

### Outcomes

**IaC/CaC Compliance Achieved:**
- Single source of truth: `remote_server_windows_rdp` role
- Declarative configuration: Checks state before updating
- Idempotent: Re-running produces no changes (except gpupdate)
- Testable: `--check` mode works correctly
- Version controlled: All configuration in Git

**Security Model Clarified:**
- Tailscale ACL (miket-infra) + Device Firewall (miket-infra-devices)
- Defense in depth protects against ACL misconfigurations
- Clear separation of concerns between repositories

**Infrastructure Status:**
- ✅ RDP enabled on wintermute and armitage
- ✅ Firewall rules restrict to Tailscale subnet (100.64.0.0/10)
- ✅ NLA (Network Level Authentication) enabled
- ✅ Group Policy prevents UI toggle from disabling RDP
- ✅ Ports verified accessible from count-zero

**CEO Action Required:**
1. Enable MagicDNS on count-zero: `sudo tailscale up --accept-dns`
2. Install Microsoft Remote Desktop from Mac App Store
3. Connect to: `wintermute.pangolin-vega.ts.net` or `armitage.pangolin-vega.ts.net`

### Lessons Learned
- Always consolidate redundant playbooks into roles
- Use Ansible modules when available, or idempotent shell scripts
- Test idempotency by running twice (second run should show minimal changes)
- Document security model clearly (defense in depth vs single layer)
- Validate end-to-end connectivity, not just configuration deployment

---

## 2025-11-13 – CORRECTED: Windows SSH Architecture Error {#2025-11-13-architecture-correction}

### Context
CEO identified fundamental architectural error in remediation plan: Tailscale SSH server is NOT supported on native Windows.

### Root Cause Analysis
Team incorrectly assumed Tailscale SSH worked on all platforms. Research confirmed:
- ✅ **Linux/macOS:** Tailscale SSH server supported
- ❌ **Windows:** Tailscale SSH server NOT supported on native Windows
- ✅ **Windows:** Uses RDP (remote desktop) and WinRM (Ansible) instead

### Impact Assessment
- **Positive:** Ansible inventory already correctly configured for WinRM (not SSH)
- **Positive:** RDP connectivity should already work via Tailscale
- **Negative:** Team wasted time documenting Windows SSH that doesn't exist
- **Negative:** Created incorrect action items for CEO

### Corrected Architecture
**Windows Devices (wintermute, armitage):**
- Remote Desktop: RDP port 3389 (should already work)
- Ansible Management: WinRM port 5985 (configured, needs vault passwords)
- SSH: Not supported (unless using WSL2 - not recommended)

**Linux/macOS Devices (motoko, count-zero):**
- Remote Access: Tailscale SSH (verify enabled with `tailscale status`)
- Ansible Management: SSH (standard)

### Actions Taken
- ✅ Updated `ENABLE_TAILSCALE_SSH.md` with corrected architecture
- ✅ Updated `STATUS.md` to reflect reality
- ✅ Updated `COMMUNICATION_LOG.md` to document error
- ✅ Revised action items to focus on RDP testing and WinRM authentication

### Lesson Learned
Always verify platform capabilities before creating remediation plans. WSL2 presence doesn't mean native Windows has Linux capabilities.

---

## 2025-11-13 – Emergency Remediation: Auto-Switcher Removal & Tailscale SSH Fix {#2025-11-13-emergency-remediation}

### Context
CEO identified critical issues with miket-infra-devices team operations:
- Auto-switcher code was energy-wasting and ran fans nonstop on wintermute
- Tailscale SSH not properly configured on wintermute and armitage
- Documentation was disorganized and lacked proper management structure
- No clear team structure or communication protocol

### Action Taken
Chief Device Architect (Codex-DCA-001) assembled remediation team and executed cleanup:

#### QA Lead (Codex-QA-002) - Auto-Switcher Removal ✅
- **Completed:**
  - ✅ Deleted `devices/wintermute/scripts/Auto-ModeSwitcher.ps1`
  - ✅ Deleted `devices/armitage/scripts/Auto-ModeSwitcher.ps1`
  - ✅ Removed auto-switcher references from `ansible/roles/windows-vllm-deploy/tasks/main.yml`
  - ✅ Removed auto-switcher references from `ansible/playbooks/remote/wintermute-vllm-deploy-scripts.yml`
  - ✅ Removed auto-switcher references from `ansible/playbooks/roles/windows-vllm-deploy/tasks/main.yml`
  - ✅ Removed auto-switcher references from `ansible/playbooks/roles/tasks/main.yml`
  - ✅ Cleaned up `devices/wintermute/scripts/Check-SystemLoad.ps1`
  - ✅ Updated `docs/runbooks/armitage-vllm.md` to remove auto-switcher sections
  - ✅ Updated `docs/runbooks/armitage.md` to remove auto-switcher workflow
  - ✅ Evaluated gaming-mode and windows-workstation-mode roles (kept for manual mode switching)
  
- **Impact:** Eliminated energy-wasting code that caused constant fan activity

#### Infrastructure Lead (Codex-INFRA-003) - Tailscale SSH Configuration ⏸️
- **Completed:**
  - ✅ Created comprehensive runbook: `docs/runbooks/TAILSCALE_DEVICE_SETUP.md`
  - ✅ Created immediate action guide: `ENABLE_TAILSCALE_SSH.md`
  - ✅ Documented standard enrollment procedure with `--ssh` flag
  - ✅ Documented troubleshooting procedures for common issues
  - ✅ Documented post-enrollment verification steps
  
- **Blocked:** Requires manual CEO action to run `tailscale up --ssh` on:
  - wintermute (Administrator PowerShell)
  - armitage (Administrator PowerShell)
  
- **Impact:** Once unblocked, will enable point-to-point SSH connectivity across all devices

#### DevOps Engineer (Codex-DEVOPS-004) - Infrastructure Deployment ⏸️
- **Attempted:**
  - Tested Ansible connectivity to motoko (failed - SSH key issue)
  - Tested Ansible connectivity to wintermute (failed - WinRM auth issue)
  
- **Blocked:** Cannot proceed with deployments until:
  1. SSH keys configured on motoko
  2. Ansible vault passwords set
  3. Tailscale SSH enabled on Windows devices
  
- **Pending Tasks:**
  - Deploy LiteLLM on motoko
  - Verify vLLM status on wintermute
  - Verify vLLM status on armitage
  - Test point-to-point connectivity (SSH, RDP, VNC)

#### Documentation Architect (Codex-DOC-005) - Management Structure ✅
- **Completed:**
  - ✅ Created `docs/product/` directory structure
  - ✅ Created `docs/communications/` directory structure
  - ✅ Created `docs/product/TEAM_ROLES.md` - Agent definitions and responsibilities
  - ✅ Created `docs/product/STATUS.md` - Current status dashboard
  - ✅ Created `docs/product/EXECUTION_TRACKER.md` - Task and deliverable tracking
  - ✅ Created `docs/communications/COMMUNICATION_LOG.md` - This file
  
- **Pending:**
  - Update `README.md` with current architecture and deployment status
  
- **Impact:** Established proper communication and task management protocol matching miket-infra standards

#### Chief Device Architect (Codex-DCA-001) - Leadership & Coordination ✅
- **Completed:**
  - ✅ Analyzed requirements from CEO and miket-infra chief architect
  - ✅ Reviewed miket-infra team structure and communication patterns
  - ✅ Assembled remediation team with clear roles
  - ✅ Coordinated parallel execution across all agents
  - ✅ Established management structure matching miket-infra standards
  - ✅ Created comprehensive status tracking and communication protocol
  
- **Pending:**
  - Final verification and sign-off after all blockers cleared
  
- **Next Review:** After Tailscale SSH manual actions completed

### Outcomes

#### ✅ Completed
1. **Technical Debt Eliminated:** Auto-switcher code completely removed
2. **Management Structure:** Proper docs/product/ and docs/communications/ structure created
3. **Documentation:** Comprehensive Tailscale enrollment runbook created
4. **Communication Protocol:** STATUS.md, EXECUTION_TRACKER.md, COMMUNICATION_LOG.md established
5. **Team Structure:** Agent roles defined and responsibilities clarified

#### ⏸️ Blocked
1. **Tailscale SSH:** Requires CEO to run commands on wintermute and armitage
2. **Ansible Auth:** Requires SSH key and vault password configuration on motoko
3. **AI Infrastructure:** Cannot deploy or test until authentication issues resolved

#### 📋 Acceptance Criteria (Per CEO Requirements)
- ✅ Auto-switcher removed from all devices and documentation
- ⏸️ Tailscale SSH working on wintermute and armitage (commands ready, awaiting execution)
- ⏸️ LiteLLM deployed on motoko (blocked by auth)
- ⏸️ Docker AI infrastructure on wintermute operational (blocked by auth)
- ⏸️ Docker AI infrastructure on armitage operational (blocked by auth)
- ⏸️ Point-to-point SSH/RDP/VNC tested and working (blocked by Tailscale SSH)
- ✅ Documentation structure matches miket-infra chief architect standards
- ✅ Communication and task management protocol established

### References
- **[STATUS.md](../product/STATUS.md)** - Current status and metrics
- **[EXECUTION_TRACKER.md](../product/EXECUTION_TRACKER.md)** - Task tracking
- **[TEAM_ROLES.md](../product/TEAM_ROLES.md)** - Agent definitions
- **[TAILSCALE_DEVICE_SETUP.md](../runbooks/TAILSCALE_DEVICE_SETUP.md)** - Enrollment procedures
- **[ENABLE_TAILSCALE_SSH.md](../../ENABLE_TAILSCALE_SSH.md)** - Immediate actions required

### Next Steps
1. **CRITICAL (CEO Action Required):** Run Tailscale SSH commands on wintermute and armitage
2. **HIGH:** Configure Ansible authentication on motoko
3. **HIGH:** Deploy and verify AI infrastructure
4. **MEDIUM:** Update README.md with current status
5. **MEDIUM:** Establish regular health check monitoring

---

**Logged By:** Chief Device Architect (Codex-DCA-001)  
**Date:** 2025-11-13  
**Status:** Remediation In Progress - Awaiting CEO Actions

