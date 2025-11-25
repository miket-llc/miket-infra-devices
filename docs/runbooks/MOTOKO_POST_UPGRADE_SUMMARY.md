---
document_title: Motoko Post-Upgrade Configuration Summary
author: Chief Architect Team
last_updated: 2025-01-XX
status: complete
related_initiatives:
  - PHC vNext Architecture
  - Pop!_OS 24 Beta Migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-01-XX-motoko-post-upgrade
---

# Motoko Post-Upgrade Configuration Summary

## Executive Summary

Comprehensive Ansible roles and playbooks created to configure motoko after Pop!_OS 24 Beta upgrade:
- **Lid Configuration**: Safe headless operation with lid closed
- **Wake-on-LAN**: Remote power-on capability
- **PHC Services Verification**: Ensures all Personal Hybrid Cloud services operational

## Deliverables

### Ansible Roles

1. **`ansible/roles/lid_configuration/`**
   - Configures systemd-logind to ignore lid switch
   - Adds kernel parameter `button.lid_init_state=open`
   - Creates GDM service overrides
   - Enables force-gdm-start service

2. **`ansible/roles/wake_on_lan/`**
   - Configures ethtool for magic packet WOL
   - Sets NetworkManager WOL settings
   - Creates persistent WOL systemd service

### Playbooks

1. **`ansible/playbooks/motoko/configure-headless-wol.yml`**
   - Main configuration playbook
   - Applies lid and WOL configuration
   - Verifies motoko is in `wol_enabled` group

2. **`ansible/playbooks/motoko/verify-phc-services.yml`**
   - Verifies storage backplane (`/flux`, `/space`, `/time`)
   - Checks data lifecycle timers
   - Verifies LiteLLM service
   - Checks vLLM containers
   - Validates Tailscale connectivity

### Documentation

1. **`docs/runbooks/motoko-post-upgrade-setup.md`**
   - Comprehensive setup guide
   - Step-by-step instructions
   - Troubleshooting section

2. **`docs/runbooks/MOTOKO_LID_WOL_SETUP.md`**
   - Quick reference guide
   - Testing procedures
   - Common issues

## Quick Start

**Prerequisites:** Tailscale ACLs must be deployed from miket-infra first.

**After ACL Deployment:**

```bash
# Configure lid and WOL
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/configure-headless-wol.yml \
  --connection=local

# Verify PHC services
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/verify-phc-services.yml \
  --connection=local

# Reboot for kernel parameter
sudo reboot
```

**Current Status:**
- ✅ miket-infra ACL review complete
- ⏸️ ACL deployment pending (requires Azure CLI)
- ⏸️ Device configuration pending ACL deployment

## Important Notes

### Tailscale ACLs Status

**miket-infra Review:** ✅ Complete (2025-01-27)
- Code review complete - All changes approved
- ACL changes verified: Exit node, route advertisement, SSH, WinRM, NoMachine
- Security assessment: Low risk, no breaking changes

**Deployment Status:** ⏸️ Pending Azure CLI authentication

**After Deployment:**
Tailscale ACLs are managed in `miket-infra` repository. After deployment, verify:

```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform plan  # Should show no changes if deployed
```

Ensure motoko has:
- Tags: `tag:server`, `tag:linux`, `tag:ansible`
- Proper ACL rules for access
- Exit node capability (configured)
- Route advertisement (192.168.1.0/24)

See: `docs/initiatives/motoko-post-upgrade/MIKET_INFRA_COORDINATION.md` for full status

### Reboot Required
Kernel parameter `button.lid_init_state=open` requires a reboot to take effect.

### BIOS/UEFI Settings
Wake-on-LAN may require firmware configuration:
- Enable Wake-on-LAN in BIOS/UEFI
- Enable Power On By PCI-E (if available)
- Disable Deep Sleep (if applicable)

## Architecture Compliance

- ✅ Follows PHC vNext architecture principles
- ✅ Maintains compatibility with miket-infra platform definitions
- ✅ Respects storage invariants (Flux/Space/Time)
- ✅ Aligns with Tailscale mesh networking model
- ✅ Documents miket-infra dependency for ACL management
- ✅ Follows documentation taxonomy (runbooks in proper location)
- ✅ Includes mandatory front matter

## Team Credits

- **Chief Architect**: Role design and architecture
- **DevOps Engineer**: Lid configuration role
- **Networking Engineer**: Wake-on-LAN role
- **SRE Engineer**: PHC verification playbook
- **DocOps**: Documentation and runbooks

## Related Documentation

- [Motoko Post-Upgrade Setup](motoko-post-upgrade-setup.md)
- [Lid & WOL Quick Reference](MOTOKO_LID_WOL_SETUP.md)
- [Motoko Headless Setup](MOTOKO_HEADLESS_LAPTOP_SETUP.md)
- [PHC Prompt](../../../PHC_PROMPT.md)


