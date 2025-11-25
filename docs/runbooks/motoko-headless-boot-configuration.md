---
# Copyright (c) 2025 MikeT LLC. All rights reserved.
document_title: Motoko Headless Boot Configuration
author: Codex-CA-001 (Chief Architect)
last_updated: 2025-11-25
status: Published
related_initiatives:
  - initiatives/motoko-headless-boot
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-25-motoko-headless-boot-configuration
---

# Motoko Headless Boot Configuration

Complete guide for configuring motoko to boot with lid closed, wake on LAN, and use HDMI as primary display (with eDP fallback) before X-windows starts.

## Overview

This configuration enables motoko (Ubuntu 24.04.2 LTS) to:
- Boot with lid closed upon Wake-on-LAN
- Use external HDMI as primary display (fallback to eDP if HDMI unplugged)
- Work before X-windows starts
- Maintain NoMachine compatibility (VNC architecturally retired)

## Quick Start

**Automated Setup:**
```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/configure-headless-boot.yml \
  --connection=local
```

## What This Configures

### 1. Lid Configuration (`lid_configuration` role)
- **systemd-logind**: Ignores lid switch events (`HandleLidSwitch=ignore`)
- **Kernel parameter**: `button.lid_init_state=open` (treats lid as always open)
- **GDM service**: Override to start with lid closed
- **Force-start service**: Ensures GDM starts on boot
- **Autologin**: Configures GDM to auto-login mdt user

### 2. Wake-on-LAN (`wake_on_lan` role)
- **ethtool**: Enables magic packet wake-on-LAN
- **NetworkManager**: Configures WOL settings
- **Persistent service**: Ensures WOL survives reboots (`wake-on-lan.service`)

### 3. Display Configuration (`display_configuration` role)
- **Xorg config**: `/etc/X11/xorg.conf.d/10-hdmi-primary.conf` (HDMI preferred)
- **Systemd service**: `display-setup.service` runs after GDM, before user session
- **Display switch script**: `/usr/local/bin/display-switch.sh` detects and configures displays
- **udev rules**: `/etc/udev/rules.d/99-hdmi-monitor.rules` handles HDMI hotplug
- **Fallback logic**: eDP becomes primary if HDMI disconnected

## Boot Sequence

1. **System boots** (or wakes via WOL) with lid closed
2. **Kernel parameter** (`button.lid_init_state=open`) treats lid as open
3. **Multi-user target** reaches
4. **Force-GDM-start service** starts GDM
5. **Xorg reads** `/etc/X11/xorg.conf.d/10-hdmi-primary.conf` (HDMI preferred)
6. **Display-setup service** runs after GDM, before user session
7. **Display switch script** detects HDMI/eDP and configures primary display
8. **GDM autologin** logs in mdt user
9. **X session starts** on `:0` with configured display
10. **NoMachine server** shares the existing session

## Display Behavior

### HDMI Connected
- HDMI becomes primary display
- eDP (laptop display) is turned off
- Works before X-windows starts

### HDMI Disconnected
- eDP becomes primary display automatically
- HDMI is ignored
- Works before X-windows starts

### HDMI Hotplug
- udev rule detects connect/disconnect
- Display reconfigures automatically
- No reboot required

## Remote Desktop

**NoMachine** is the sole remote desktop solution:
- **Host**: `motoko.pangolin-vega.ts.net:4000`
- **Protocol**: NoMachine NX
- **Session**: Shares existing GNOME desktop session
- **Display**: Sees configured display (HDMI or eDP)

**VNC has been architecturally retired** (2025-11-22). All VNC services, scripts, and documentation have been removed or archived.

## Testing

### Test Lid-Closed Boot
1. Close laptop lid
2. Reboot system
3. Verify system boots normally
4. Check external display is active (HDMI if connected, eDP if not)

### Test Wake-on-LAN
From another device:
```bash
cd ~/miket-infra-devices
poetry run python tools/cli/tailnet.py wake --host motoko
```

Verify motoko wakes from powered-off state.

### Test Display Configuration
1. **With HDMI connected**: Verify HDMI is primary display
2. **Unplug HDMI**: Verify eDP becomes primary automatically
3. **Plug HDMI back in**: Verify HDMI becomes primary again
4. **Connect via NoMachine**: Verify you see the configured display

### Test NoMachine Connection
1. Connect from another device: `motoko.pangolin-vega.ts.net:4000`
2. Verify you see the desktop session
3. Verify display matches physical configuration (HDMI or eDP)

## Troubleshooting

### GDM Not Starting
```bash
sudo systemctl status force-gdm-start.service
sudo systemctl start gdm3
sudo systemctl status gdm3
```

### Display Not Configuring
```bash
# Check display setup service
sudo systemctl status display-setup.service
sudo journalctl -u display-setup.service -n 50

# Manual display configuration
sudo /usr/local/bin/display-switch.sh

# Check Xorg config
cat /etc/X11/xorg.conf.d/10-hdmi-primary.conf
```

### HDMI Not Detected
```bash
# Check available displays
DISPLAY=:0 xrandr --query

# Check udev rules
cat /etc/udev/rules.d/99-hdmi-monitor.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=drivers --action=change
```

### NoMachine Not Working
```bash
sudo systemctl status nxserver
sudo systemctl restart nxserver
sudo journalctl -u nxserver -n 50
```

### WOL Not Working
```bash
# Check WOL service
sudo systemctl status wake-on-lan.service

# Check ethtool settings
sudo ethtool <interface_name> | grep -i wake

# Check NetworkManager
nmcli connection show --active
```

## Important Notes

### Reboot Required
- Kernel parameter (`button.lid_init_state=open`) requires reboot
- Xorg config changes require reboot for full effect
- Display setup service will work on subsequent boots

### BIOS/UEFI Settings
Wake-on-LAN may require firmware-level configuration:
- Wake-on-LAN enabled
- Power On By PCI-E enabled
- Deep Sleep disabled (if applicable)

### Tailscale ACLs
Tailscale ACLs are defined in `miket-infra`, not this repo. After configuration, verify:
```bash
cd ~/miket-infra/infra/tailscale/entra-prod
terraform plan
```

Ensure motoko has proper tags and ACL rules.

## Related Documentation

- [Motoko Lid Configuration and Wake-on-LAN Setup](MOTOKO_LID_WOL_SETUP.md)
- [Motoko Headless Laptop Setup](MOTOKO_HEADLESS_LAPTOP_SETUP.md)
- [NoMachine Client Installation](nomachine-client-installation.md)

## Architecture Notes

This configuration follows PHC vNext architecture principles:
- **No VNC**: VNC has been architecturally retired (2025-11-22)
- **NoMachine only**: Single remote desktop protocol across all platforms
- **Early boot configuration**: Display setup works before X-windows starts
- **Dynamic fallback**: Automatic display switching based on HDMI connection
- **No interference**: Display configuration doesn't interfere with NoMachine



