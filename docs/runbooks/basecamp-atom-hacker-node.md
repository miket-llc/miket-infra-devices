# Basecamp Atom - Hacker Node Runbook

## Overview

Atom is configured as a **basecamp/hacker node** - a lightweight, portable appliance for:
- Network analysis and security research
- SDR and RF experimentation
- Serial communication and LoRa development
- Field-portable operations

**Hardware:** Lenovo ThinkPad X1 Carbon (2012)
- CPU: Intel Core i7-3667U (2C/4T)
- RAM: 8GB
- Storage: 224GB SSD
- Battery: Built-in UPS (never sleep, shutdown at 2%)

## Desktop Environments

Atom provides **two tiling window managers** selectable at login:

### Sway (Wayland) - Recommended
- Modern, efficient Wayland compositor
- Native Wayland apps run natively
- Touch input works out of the box
- Lower resource usage

### i3 (X11) - Fallback
- Traditional X11 window manager
- Better compatibility with legacy apps
- Use if Wayland has issues with specific hardware

## Workspaces

Both Sway and i3 use the same workspace layout:

| Workspace | Purpose | Typical Apps |
|-----------|---------|--------------|
| 1-term | Terminal/CLI | alacritty, tmux |
| 2-rf | RF/SDR tools | gqrx |
| 3-net | Network tools | wireshark, nmap |
| 4-lora | Serial/LoRa | minicom, screen |
| 5-notes | Documentation | firefox |

## Keybindings

**Mod key = Super/Win key**

| Binding | Action |
|---------|--------|
| Mod+Enter | Open terminal |
| Mod+d | Application launcher |
| Mod+Shift+q | Close window |
| Mod+1-5 | Switch workspace |
| Mod+Shift+1-5 | Move window to workspace |
| Mod+l | Lock screen |
| Mod+f | Fullscreen toggle |
| Mod+Shift+space | Toggle floating |
| Mod+r | Resize mode |
| Mod+h/j/k/semicolon | Focus left/down/up/right |
| Mod+Shift+e | Exit session |

## Basecamp Scripts

All scripts are in `~/basecamp/bin/` and added to PATH.

### basecamp-status
System overview showing CPU, memory, battery, network, USB devices.

```bash
basecamp-status
```

### basecamp-serial-console
Interactive serial console helper.

```bash
# List available ports
basecamp-serial-console

# Connect to port
basecamp-serial-console /dev/ttyUSB0 115200
```

### basecamp-net-scan
Safe local network scanning.

```bash
# Scan local subnet
basecamp-net-scan

# Scan specific target
basecamp-net-scan 192.168.1.0/24
```

### basecamp-sdr-gqrx
Launch GQRX SDR application.

```bash
basecamp-sdr-gqrx
```

## Tool Reference

### Networking
| Tool | Purpose |
|------|---------|
| tcpdump | Packet capture |
| tshark | CLI packet analysis |
| nmap | Network scanning |
| mtr | Traceroute + ping |
| iperf3 | Bandwidth testing |

### SDR
| Tool | Purpose |
|------|---------|
| gqrx | SDR receiver GUI |
| rtl_test | RTL-SDR diagnostics |
| rtl_fm | FM demodulation |
| gnuradio | Signal processing |

### Serial
| Tool | Purpose |
|------|---------|
| screen | Terminal + serial |
| minicom | Classic serial terminal |
| picocom | Minimal serial terminal |

## Directory Structure

```
~/basecamp/
├── bin/        # Helper scripts
├── logs/       # Rotated logs
├── captures/   # pcaps, RF captures
├── notes/      # Documentation
└── configs/    # Local overrides
```

## Hardware Access

### Serial Devices
User `mdt` is in `dialout` group - no sudo required for `/dev/ttyUSB*`.

### SDR Devices
udev rules configured for RTL-SDR and HackRF. No root required.

Verify with:
```bash
# Should show device without sudo
rtl_test -t
```

## Deployment

### Full Deployment
```bash
make deploy-basecamp
# or
ansible-playbook -i ansible/inventory/hosts.yml \
    ansible/playbooks/atom/deploy-basecamp.yml
```

### Validation
```bash
make validate-basecamp
# or
ansible-playbook -i ansible/inventory/hosts.yml \
    ansible/playbooks/atom/validate-basecamp.yml
```

### Specific Components (via tags)
```bash
# UI only
ansible-playbook ... --tags ui

# Tools only
ansible-playbook ... --tags tools

# Security only
ansible-playbook ... --tags security
```

## Troubleshooting

### Display Manager Won't Start
```bash
# Check greetd/SDDM status
systemctl status greetd
systemctl status sddm

# Check logs
journalctl -u greetd -b
```

### Sway Won't Start
```bash
# Start manually to see errors
sway

# Check Wayland socket
ls -la $XDG_RUNTIME_DIR/wayland-*
```

### i3 Won't Start
```bash
# Start manually
startx /usr/bin/i3

# Check X server
cat ~/.local/share/xorg/Xorg.0.log | tail -50
```

### SDR Device Not Detected
```bash
# Check USB detection
lsusb | grep -iE 'RTL|HackRF'

# Check permissions
ls -la /dev/bus/usb/*/*

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Serial Port Permission Denied
```bash
# Verify group membership
groups

# If dialout missing, re-login or:
newgrp dialout
```

## Security Configuration

### SSH Access
- Key-only authentication
- Password auth disabled
- Root login disabled
- Tailscale-only access

### Firewall
- Default deny inbound
- SSH only via Tailnet (100.64.0.0/10)
- node_exporter port 9100 (Tailnet only)

### SELinux
- Enforcing mode
- sshd_t in permissive (Tailscale SSH workaround)

## Performance Targets

| Metric | Target |
|--------|--------|
| Idle RAM | < 800MB |
| Boot to login | < 30s |
| Battery on idle | 4-5 hours |

Measure with:
```bash
# Memory
free -h

# Boot time
systemd-analyze

# Battery
cat /sys/class/power_supply/BAT0/capacity
```

## Known Limitations

1. **SDRangel omitted** - Too heavy for 8GB system. Use gqrx instead.
2. **Wireshark GUI omitted** - Use tshark CLI to save memory.
3. **No container runtime** - Podman/Docker disabled by design.
4. **No network mounts** - CIFS removed for resilience.

## Related Documentation

- [CLAUDE.md](../../CLAUDE.md) - Project conventions
- [COMMUNICATION_LOG.md](../communications/COMMUNICATION_LOG.md) - Architecture decisions
- [atom host_vars](../../ansible/host_vars/atom.yml) - Configuration
