---
document_title: Motoko Lid Configuration and Wake-on-LAN Setup
author: Chief Architect Team
last_updated: 2025-01-XX
status: active
related_initiatives:
  - PHC vNext Architecture
  - Pop!_OS 24 Beta Migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-01-XX-motoko-post-upgrade
---

# Motoko Lid Configuration and Wake-on-LAN Setup

## Quick Reference

**Automated Setup:**
```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/configure-headless-wol.yml \
  --connection=local
```

**Verify PHC Services:**
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/verify-phc-services.yml \
  --connection=local
```

## What This Configures

### Lid Configuration
- **systemd-logind**: Ignores lid switch events
- **Kernel parameter**: `button.lid_init_state=open`
- **GDM service**: Override to start with lid closed
- **Force-start service**: Ensures GDM starts on boot

### Wake-on-LAN
- **ethtool**: Enables magic packet wake-on-LAN
- **NetworkManager**: Configures WOL settings
- **Persistent service**: Ensures WOL survives reboots

### PHC Services Verification
- Storage backplane mounts (`/flux`, `/space`, `/time`)
- Data lifecycle timers
- LiteLLM service
- vLLM containers
- Tailscale connectivity

## Important Notes

### Tailscale ACLs
Tailscale ACLs are defined in `miket-infra`, not this repo. After configuration, verify:

```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform plan
```

Ensure motoko has proper tags and ACL rules.

### Reboot Required
Kernel parameter (`button.lid_init_state=open`) requires a reboot to take effect.

### BIOS/UEFI Settings
Wake-on-LAN may require firmware-level configuration. Check BIOS/UEFI settings for:
- Wake-on-LAN enabled
- Power On By PCI-E enabled
- Deep Sleep disabled (if applicable)

## Testing

### Test WOL
From another device:
```bash
cd ~/miket-infra-devices
poetry run python tools/cli/tailnet.py wake --host motoko
```

### Test Lid-Closed Operation
1. Close laptop lid
2. Verify system continues operating
3. Check external display is primary
4. Verify NoMachine/Tailscale SSH still works

## Troubleshooting

See [Motoko Post-Upgrade Setup Runbook](motoko-post-upgrade-setup.md) for detailed troubleshooting.


