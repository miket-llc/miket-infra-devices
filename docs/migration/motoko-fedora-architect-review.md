# Chief Architect Review: Motoko Fedora Migration

**Date:** 2025-01-XX  
**Status:** Pre-Migration Review  
**Context:** Team upgrading motoko from Pop_OS/Ubuntu to Fedora 43 for better hardware support

---

## Executive Summary

The team has prepared a comprehensive migration plan from Ubuntu 24.04 (Pop_OS) to Fedora 43 Workstation. The migration addresses kernel and hardware compatibility issues while maintaining PHC service continuity.

**Key Migration Points:**
- ✅ Migration plan documented (`docs/migration/motoko-ubuntu-to-fedora-43.md`)
- ✅ Bootstrap script created (`ansible/scripts/bootstrap-motoko-fedora.sh`)
- ✅ Fedora base playbook ready (`ansible/playbooks/motoko/fedora-base.yml`)
- ✅ Minimal post-install commands prepared (`docs/migration/motoko-fedora-post-install-minimal.md`)

---

## Recent Changes Review

### 1. Fedora Migration Infrastructure (Commit: 1d2da62)

**Added:**
- `ansible/scripts/bootstrap-motoko-fedora.sh` - Automated bootstrap script
- `ansible/playbooks/motoko/fedora-base.yml` - Complete Fedora base configuration
- `docs/migration/motoko-ubuntu-to-fedora-43.md` - Comprehensive migration guide

**Assessment:** ✅ **APPROVED**
- Bootstrap script follows PHC patterns (Ansible-driven, no manual config)
- Playbook covers all critical services (NVIDIA, Docker, Tailscale, Samba, NoMachine)
- Migration plan is thorough with rollback procedures

### 2. Desktop Environment Changes (Commits: f838c90, cc3b2e6)

**Context:** Previous migration from COSMIC/Wayland to KDE Plasma/X11

**Current State:**
- Ubuntu 24.04 with KDE Plasma on X11
- NoMachine configured for X11 session sharing
- SDDM display manager

**Fedora Target:**
- Fedora 43 Workstation with GNOME on X11 (not Wayland)
- GDM display manager
- NoMachine will need reconfiguration

**Assessment:** ⚠️ **REVIEW REQUIRED**
- Desktop environment change (KDE → GNOME) is acceptable
- X11 requirement maintained (good for NoMachine compatibility)
- Need to verify NoMachine works with GNOME/X11 (not just KDE/X11)

### 3. Tailscale Configuration

**Current Configuration:**
- Tags: `tag:server`, `tag:linux`, `tag:ansible`
- SSH enabled
- MagicDNS enabled
- Subnet routes: `192.168.1.0/24`
- Exit node capability

**Fedora Playbook Coverage:**
- ✅ Tailscale installation
- ✅ Service enablement
- ⚠️ **MISSING:** Automatic connection with enrollment key
- ⚠️ **MISSING:** Tag configuration in playbook

**Assessment:** ⚠️ **NEEDS ATTENTION**
- Playbook installs Tailscale but doesn't connect it
- Manual step required: `sudo tailscale up --auth-key=<KEY> --ssh --accept-dns`
- Should integrate Tailscale role (`ansible/roles/tailscale`) into fedora-base.yml

---

## Critical Path Analysis

### Stage 3: First Boot (Current Focus)

**Requirement:** Minimal keystrokes to enable remote access

**Current Solution:**
```bash
sudo dnf install -y openssh-server tailscale
sudo systemctl enable --now sshd
sudo tailscale up --auth-key=<KEY> --ssh --accept-dns --accept-routes --advertise-routes=192.168.1.0/24
```

**Assessment:** ✅ **ADEQUATE**
- Minimal commands (3 lines)
- SSH fallback if Tailscale fails
- Enrollment key can be provided by team or retrieved from miket-infra

**Recommendation:** 
- Document enrollment key retrieval: `cd ~/miket-infra/infra/tailscale/entra-prod && terraform output -raw enrollment_key`
- Consider one-liner version for copy-paste

### Stage 4: Remote Bootstrap

**Bootstrap Script:** `ansible/scripts/bootstrap-motoko-fedora.sh`

**Process:**
1. Enable RPM Fusion
2. Install Ansible
3. Clone/update miket-infra-devices
4. Run `fedora-base.yml` playbook
5. Verification checks

**Assessment:** ✅ **SOUND**
- Follows PHC patterns (Ansible-driven)
- Idempotent (can re-run safely)
- Includes verification steps

**Gap Identified:**
- Bootstrap script expects `playbooks/motoko/fedora-base.yml` to exist
- If playbook missing, falls back to `verify-phc-services.yml` (may not exist)
- Should create fedora-base.yml if missing or fail gracefully

---

## Architecture Compliance

### PHC Invariants

| Invariant | Status | Notes |
|-----------|--------|-------|
| `/space` = SoR | ✅ Preserved | Mounted, not formatted |
| `/flux` = Runtime | ✅ Preserved | Mounted, not formatted |
| `/time` = Time Machine | ✅ Preserved | Read-only mount |
| Ansible = Config SoT | ✅ Maintained | All config via playbooks |
| Secrets from AKV | ✅ Maintained | No hardcoded secrets |
| Tailscale = Private Mesh | ✅ Maintained | SSH enabled, MagicDNS |

### Service Continuity

| Service | Status | Notes |
|---------|--------|-------|
| Docker + NVIDIA | ✅ Configured | Runtime configured in playbook |
| vLLM Reasoning | ⚠️ Post-bootstrap | Requires Docker first |
| vLLM Embeddings | ⚠️ Post-bootstrap | Requires Docker first |
| LiteLLM Proxy | ⚠️ Post-bootstrap | Requires Docker first |
| Samba | ✅ Configured | Playbook installs and configures |
| NoMachine | ✅ Configured | Playbook installs and configures |
| Tailscale | ⚠️ Manual step | Needs enrollment key connection |
| fail2ban | ✅ Configured | Playbook installs and enables |

---

## Recommendations

### Immediate (Pre-Migration)

1. **Test NoMachine with GNOME/X11**
   - Verify NoMachine 9.2.18 works with GNOME on X11 (not just KDE)
   - Document any required configuration changes

2. **Integrate Tailscale Role**
   - Add `ansible/roles/tailscale` to `fedora-base.yml`
   - Configure tags via variables: `tailscale_device_tags[motoko]`
   - Automate connection with enrollment key (from AKV or variable)

3. **Verify Enrollment Key Access**
   - Confirm team can retrieve enrollment key from miket-infra
   - Document retrieval process in minimal commands doc

### Post-Migration

1. **Update Device Config**
   - Update `devices/motoko/config.yml` with Fedora 43 details
   - Change OS: `Ubuntu 24.04 LTS` → `Fedora 43`
   - Change desktop: `KDE Plasma` → `GNOME`
   - Update kernel version

2. **Update Communication Log**
   - Document migration completion in `docs/communications/COMMUNICATION_LOG.md`
   - Note any deviations from plan

3. **Service Verification**
   - Run `verify-phc-services.yml` playbook
   - Test all API endpoints (vLLM, LiteLLM)
   - Verify Samba shares accessible
   - Test NoMachine connection

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| NoMachine incompatible with GNOME/X11 | Low | Medium | Test before migration; fallback to VNC if needed |
| Enrollment key unavailable | Low | High | Document manual login process; keep SSH fallback |
| NVIDIA drivers fail | Medium | High | Playbook includes driver install; reboot required |
| Storage mounts fail | Low | Critical | Verify UUIDs before migration; test fstab |
| Service deployment fails | Low | Medium | Bootstrap script includes verification; can re-run |

---

## Approval Status

**Overall Assessment:** ✅ **APPROVED WITH CONDITIONS**

**Conditions:**
1. Test NoMachine with GNOME/X11 before migration
2. Integrate Tailscale role into fedora-base.yml (or document manual step clearly)
3. Verify enrollment key retrieval process works

**Ready for Execution:** ✅ **YES** (after conditions met)

---

## Next Steps

1. **Team Action:** Test NoMachine with GNOME/X11 on test system
2. **Team Action:** Integrate Tailscale role or document manual connection clearly
3. **Team Action:** Verify enrollment key access from miket-infra
4. **User Action:** Execute minimal commands after Fedora installation
5. **Team Action:** Connect via Tailscale SSH and run bootstrap script
6. **Team Action:** Complete Ansible-driven configuration
7. **Team Action:** Verify all services operational

---

**Reviewed By:** Chief Architect  
**Date:** 2025-01-XX  
**Status:** Ready for migration (pending conditions)


