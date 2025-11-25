---
document_title: Motoko Post-Upgrade Setup Runbook
author: Chief Architect Team
last_updated: 2025-01-XX
status: active
related_initiatives:
  - PHC vNext Architecture
  - Pop!_OS 24 Beta Migration
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-01-XX-motoko-post-upgrade
---

# Motoko Post-Upgrade Setup Runbook

## Overview

This runbook guides you through configuring motoko after upgrading to Pop!_OS 24 Beta, ensuring:
- Safe lid-closed operation (headless laptop)
- Wake-on-LAN functionality
- PHC (Personal Hybrid Cloud) services verification
- Tailscale connectivity and DNS

## Prerequisites

- Physical or NoMachine access to motoko
- sudo/root access
- Ansible installed on motoko (or run from control node)

## Quick Start

### Option 1: Automated Playbook (Recommended)

From motoko:

```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/configure-headless-wol.yml \
  --connection=local
```

Then verify PHC services:

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/verify-phc-services.yml \
  --connection=local
```

### Option 2: Manual Configuration

Follow the steps below if you prefer manual configuration.

## Step-by-Step Configuration

### 1. Fix DNS and Tailscale (If Needed)

If DNS isn't working after upgrade, run:

```bash
cd ~/miket-infra-devices/devices/motoko
sudo ./fix-dns-automated.sh
```

Or use the copy-paste fix from `COPY_PASTE_FIX.txt`.

### 2. Configure Lid for Headless Operation

The lid configuration role handles:
- systemd-logind configuration (ignore lid switch)
- Kernel parameter (`button.lid_init_state=open`)
- GDM service overrides
- Force-GDM-start service

**Run via Ansible:**
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/configure-headless-wol.yml \
  --connection=local \
  --tags lid
```

**Or manually:**
```bash
# Configure logind
sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=ignore/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

# Add kernel parameter (Pop!_OS)
sudo kernelstub -a 'button.lid_init_state=open'

# Create GDM override
sudo mkdir -p /etc/systemd/system/gdm.service.d
sudo tee /etc/systemd/system/gdm.service.d/override.conf > /dev/null <<EOF
[Unit]
ConditionPathExists=
ConditionPathExists=/usr/sbin/gdm3

[Service]
Restart=always
RestartSec=5
EOF

# Create force-start service
sudo tee /etc/systemd/system/force-gdm-start.service > /dev/null <<EOF
[Unit]
Description=Force GDM to start
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl start gdm3
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable force-gdm-start.service
```

### 3. Configure Wake-on-LAN

The WOL role handles:
- ethtool configuration
- NetworkManager WOL settings
- Persistent WOL service

**Run via Ansible:**
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/configure-headless-wol.yml \
  --connection=local \
  --tags wol
```

**Or manually:**
```bash
# Find interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# Install ethtool if needed
sudo apt install -y ethtool

# Enable WOL
sudo ethtool -s $INTERFACE wol g

# Configure NetworkManager
CONNECTION=$(nmcli -t -f NAME connection show --active | head -1)
sudo nmcli connection modify "$CONNECTION" 802-3-ethernet.wake-on-lan magic
sudo nmcli connection up "$CONNECTION"

# Create persistent service
sudo tee /etc/systemd/system/wake-on-lan.service > /dev/null <<EOF
[Unit]
Description=Enable Wake-on-LAN
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $INTERFACE wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wake-on-lan.service
```

### 4. Verify PHC Services

Run the verification playbook:

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/verify-phc-services.yml \
  --connection=local
```

This checks:
- Storage backplane (`/flux`, `/space`, `/time`)
- Data lifecycle timers
- LiteLLM service
- vLLM containers
- Tailscale connectivity

### 5. Check Tailscale ACLs (miket-infra)

**Important:** Tailscale ACLs are defined in `miket-infra`, not this repo.

**Status:** ✅ miket-infra team has completed ACL review (2025-01-27)
- Code review complete - All changes approved
- Deployment pending Azure CLI authentication
- See: `docs/communications/COMMUNICATION_LOG.md#2025-01-27-miket-infra-acl-review`

**After ACL Deployment:**

Verify ACLs are deployed:

```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform plan  # Should show no changes if deployed
```

Ensure motoko has:
- Tags: `tag:server`, `tag:linux`, `tag:ansible`
- Exit node capability (if needed)
- Proper ACL rules for access

**ACL Changes Include:**
- Exit node rules for motoko
- Route advertisement rules (192.168.1.0/24)
- SSH, WinRM, and NoMachine access rules
- MagicDNS configuration

### 6. Reboot and Verify

After configuration:

```bash
sudo reboot
```

After reboot, verify:
- System boots with lid closed
- External display (HDMI) is primary
- Tailscale connects automatically
- WOL works (test from another device)

## Testing Wake-on-LAN

From another device on the tailnet:

```bash
# Using CLI tool
cd ~/miket-infra-devices
poetry run python tools/cli/tailnet.py wake --host motoko

# Or using wakeonlan directly
wakeonlan <MOTOKO_MAC_ADDRESS>
```

Get MAC address:
```bash
# On motoko
ip link show $(ip route | grep default | awk '{print $5}' | head -1) | grep -oP '(?<=link/ether )[^ ]*'
```

## Troubleshooting

### Lid Configuration Not Working

- Verify kernel parameter: `cat /proc/cmdline | grep lid_init_state`
- Check logind: `systemctl status systemd-logind`
- Verify GDM override: `systemctl cat gdm.service`

### Wake-on-LAN Not Working

- Check ethtool: `ethtool <interface> | grep Wake-on`
- Verify NetworkManager: `nmcli connection show <connection> | grep wake-on-lan`
- Check BIOS/UEFI settings (may need to enable WOL in firmware)
- Verify switch/router allows broadcast packets

### PHC Services Not Running

- Check storage mounts: `df -h | grep -E 'flux|space|time'`
- Verify timers: `systemctl list-timers | grep -E 'flux|space'`
- Check LiteLLM: `systemctl status litellm`
- Check Docker: `docker ps | grep vllm`

## Related Documentation

- [Lid Configuration Role](../../ansible/roles/lid_configuration/)
- [Wake-on-LAN Role](../../ansible/roles/wake_on_lan/)
- [PHC Prompt](../../../PHC_PROMPT.md)
- [Motoko Headless Setup](MOTOKO_HEADLESS_LAPTOP_SETUP.md)
- [Tailscale Integration](../tailscale-integration.md)

## Architecture Notes

This configuration ensures motoko operates as a headless server while maintaining:
- **Storage Backplane**: `/flux`, `/space`, `/time` mounts operational
- **AI Fabric**: LiteLLM and vLLM services accessible
- **Remote Access**: Tailscale SSH and NoMachine operational
- **Power Management**: WOL enables remote power-on

All configurations follow PHC vNext architecture principles and maintain compatibility with miket-infra platform definitions.


