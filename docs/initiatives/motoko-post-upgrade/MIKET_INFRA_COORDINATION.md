---
document_title: miket-infra Coordination Status - Motoko Post-Upgrade
author: Chief Architect Team
last_updated: 2025-01-27
status: active
related_initiatives:
  - PHC vNext Architecture
  - Pop!_OS 24 Beta Migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-01-27-miket-infra-acl-review
---

# miket-infra Coordination Status - Motoko Post-Upgrade

## Overview

This document tracks coordination between `miket-infra-devices` and `miket-infra` repositories for motoko post-upgrade configuration, specifically Tailscale ACL updates.

## Status Summary

**miket-infra Review:** ✅ Complete (2025-01-27)
**ACL Deployment:** ⏸️ Pending Azure CLI authentication
**Device Configuration:** ⏸️ Pending ACL deployment

## miket-infra Work Completed

### Code Review
- ✅ Reviewed ACL changes in `infra/tailscale/entra-prod/main.tf`
- ✅ Verified all required tags (`tag:server`, `tag:linux`, `tag:ansible`)
- ✅ Confirmed SSH rules for Ansible control node access
- ✅ Verified WinRM rules for Windows device management
- ✅ Confirmed NoMachine port 4000 access rules
- ✅ Verified exit node configuration
- ✅ Confirmed route advertisement rules (192.168.1.0/24)

### Documentation Created
- ✅ `TAILSCALE_ACL_VERIFICATION_SUMMARY.md` - Verification checklist
- ✅ `TAILSCALE_ACL_DEPLOYMENT_REVIEW.md` - Chief Architect review
- ✅ `CHIEF_ARCHITECT_REVIEW_SUMMARY.md` - Executive summary
- ✅ Communication log updated
- ✅ Execution tracker updated

### ACL Changes Summary

**New Rules Added:**
1. **Exit Node Rules (lines 93-100):** Allow devices to use motoko as exit node
2. **Route Advertisement Rules (lines 102-108):** Allow motoko to advertise routes
3. **Route Auto-Approval (lines 220-227):** Auto-approve 192.168.1.0/24 routes
4. **Test Cases (lines 258-267):** Validate exit node and route advertisement

**Security Assessment:**
- Low risk - ACL policy update only
- No breaking changes
- Maintains least-privilege access model

## Deployment Requirements

### Prerequisites
- Azure CLI installed and authenticated
- Access to Azure subscription
- Terraform access to Tailscale resources

### Deployment Steps

```bash
# Authenticate to Azure
az login
az account set --subscription <subscription-id>

# Deploy changes
cd ~/miket-infra/infra/tailscale/entra-prod
terraform init
terraform plan  # Review changes
terraform apply  # Deploy ACL updates
```

### Post-Deployment Verification

Wait 2-3 minutes for ACL propagation, then verify:

```bash
# From motoko
tailscale status
tailscale status --json | jq '.Self.Tags'

# Test SSH
tailscale ssh mdt@count-zero.pangolin-vega.ts.net "hostname"

# Test WinRM (via Ansible)
ansible windows -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping

# Test MagicDNS
ping motoko.pangolin-vega.ts.net
ping wintermute.pangolin-vega.ts.net

# Test NoMachine
nc -zv motoko.pangolin-vega.ts.net 4000
```

## miket-infra-devices Work Status

### Completed
- ✅ Ansible roles: `lid_configuration`, `wake_on_lan`
- ✅ Playbooks: `configure-headless-wol.yml`, `verify-phc-services.yml`
- ✅ Documentation: `motoko-post-upgrade-setup.md`, `MOTOKO_LID_WOL_SETUP.md`
- ✅ Communication log entry created

### Pending ACL Deployment
- ⏸️ Device configuration playbooks (can run after ACL deployment)
- ⏸️ Tailscale connectivity verification
- ⏸️ PHC service verification

## Next Steps

### Immediate (miket-infra)
1. Authenticate to Azure CLI
2. Run `terraform plan` to review changes
3. Run `terraform apply` to deploy ACL updates
4. Verify ACL propagation (2-3 minutes)
5. Update communication log with deployment status

### After ACL Deployment (miket-infra-devices)
1. Run device configuration on motoko:
   ```bash
   cd ~/miket-infra-devices
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/motoko/configure-headless-wol.yml \
     --connection=local
   ```

2. Verify PHC services:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/motoko/verify-phc-services.yml \
     --connection=local
   ```

3. Test connectivity:
   - SSH to all devices
   - WinRM to Windows devices
   - NoMachine access
   - MagicDNS resolution

4. Reboot motoko for kernel parameter:
   ```bash
   sudo reboot
   ```

5. Final verification after reboot:
   - Lid-closed operation
   - Wake-on-LAN functionality
   - All PHC services operational

## Dependencies

**miket-infra-devices depends on:**
- ✅ ACL code review (complete)
- ⏸️ ACL deployment (pending)
- ⏸️ ACL propagation (pending)

**After ACL deployment:**
- Device configuration can proceed
- Connectivity tests can run
- PHC verification can complete

## Coordination Notes

- Both repositories follow PHC vNext architecture principles
- Changes maintain compatibility between repos
- Documentation follows required taxonomy
- Communication logs updated in both repos
- Execution trackers synchronized

## Related Documentation

**miket-infra:**
- `docs/initiatives/device-onboarding/TAILSCALE_ACL_VERIFICATION_SUMMARY.md`
- `docs/initiatives/device-onboarding/TAILSCALE_ACL_DEPLOYMENT_REVIEW.md`
- `docs/initiatives/device-onboarding/CHIEF_ARCHITECT_REVIEW_SUMMARY.md`

**miket-infra-devices:**
- `docs/runbooks/motoko-post-upgrade-setup.md`
- `docs/runbooks/MOTOKO_LID_WOL_SETUP.md`
- `docs/communications/COMMUNICATION_LOG.md#2025-01-27-miket-infra-acl-review`

## Success Criteria

- ✅ ACL code review complete
- ⏸️ ACL deployment successful
- ⏸️ ACL propagation verified
- ⏸️ Device configuration complete
- ⏸️ All connectivity tests pass
- ⏸️ PHC services verified
- ⏸️ Lid-closed operation verified
- ⏸️ Wake-on-LAN verified

---

**Last Updated:** 2025-01-27
**Next Review:** After ACL deployment


