# Remote Desktop Connection Cheatsheet

Generated: 2025-11-26
Updated: VNC/RDP retired, NoMachine standardized

## Overview

**NoMachine is the sole remote desktop solution.** VNC and RDP were architecturally retired on 2025-11-22. All hosts use NoMachine on port 4000 over Tailscale.

## Connection Methods

### All Platforms
- **GUI**: NoMachine client application
- **Port**: 4000 (NoMachine default)
- **Authentication**: System credentials via NoMachine

### Installation

**Linux:**
```bash
# Installed via Ansible role: remote_client_linux_nomachine
ansible-playbook playbooks/remote_clients_nomachine.yml -l linux
```

**Windows:**
```bash
# Installed via Ansible role: remote_client_windows_nomachine
ansible-playbook playbooks/remote_clients_nomachine.yml -l windows
```

**macOS:**
```bash
# Installed via Ansible role: remote_client_macos_nomachine
ansible-playbook playbooks/remote_clients_nomachine.yml -l macos
```

## Host Connections

### MOTOKO (Linux Server)

- **Hostname**: `motoko.pangolin-vega.ts.net` (MagicDNS)
- **Protocol**: NoMachine
- **Port**: 4000
- **Session**: Shares existing KDE Plasma session
- **Quick Connect**: Open NoMachine → Select "motoko" from saved connections

### WINTERMUTE (Windows Workstation)

- **Hostname**: `wintermute.pangolin-vega.ts.net` (MagicDNS)
- **Protocol**: NoMachine
- **Port**: 4000
- **Session**: Shares existing Windows desktop
- **Quick Connect**: Open NoMachine → Select "wintermute" from saved connections

### ARMITAGE (Windows Laptop)

- **Hostname**: `armitage.pangolin-vega.ts.net` (MagicDNS)
- **Protocol**: NoMachine
- **Port**: 4000
- **Session**: Shares existing Windows desktop
- **Quick Connect**: Open NoMachine → Select "armitage" from saved connections

### COUNT-ZERO (macOS Laptop)

- **Hostname**: `count-zero.pangolin-vega.ts.net` (MagicDNS)
- **Protocol**: NoMachine
- **Port**: 4000
- **Session**: Shares existing macOS desktop
- **Quick Connect**: Open NoMachine → Select "count-zero" from saved connections


## Troubleshooting

### Connection Issues

1. **Verify Tailscale connectivity**:
   ```bash
   ping HOSTNAME.pangolin-vega.ts.net
   ```

2. **Check NoMachine service status**:
   - Linux: `systemctl status nxserver`
   - Windows: Check NoMachine Server in system tray
   - macOS: Check NoMachine Server in menu bar

3. **Verify port 4000 is listening**:
   ```bash
   # From remote host
   ss -tlnp | grep 4000  # Linux
   netstat -an | findstr 4000  # Windows
   ```

### Common Issues

**Black screen or connection refused:**
- Ensure NoMachine server is running on target host
- Check if firewall allows port 4000 from Tailscale subnet
- Verify nxserver is configured: `/usr/NX/bin/nxserver --status`

**Slow performance:**
- NoMachine auto-adjusts quality based on bandwidth
- Check Tailscale connection quality: `tailscale status`
- Consider enabling hardware encoding in NoMachine settings

**Session not visible:**
- NoMachine shares the existing physical session
- Ensure user is logged in on the target host
- Check display configuration: `/usr/NX/bin/nxserver --displaylist`

## Security Notes

- All connections are restricted to Tailscale network (100.64.0.0/10)
- No public ports are exposed
- **MagicDNS**: Use `.pangolin-vega.ts.net` hostnames for automatic resolution
- NoMachine uses NX protocol with built-in encryption

## Quick Reference

| Host | Protocol | Port | Session Type |
|------|----------|------|--------------|
| motoko | NoMachine | 4000 | KDE Plasma (Linux) |
| wintermute | NoMachine | 4000 | Windows Desktop |
| armitage | NoMachine | 4000 | Windows Desktop |
| count-zero | NoMachine | 4000 | macOS Desktop |

## Deprecated (Do Not Use)

The following are **architecturally retired** as of 2025-11-22:
- VNC (port 5900) - all servers, clients, and scripts removed
- RDP (port 3389) - disabled on Windows hosts
- xRDP - removed from Linux hosts

Use NoMachine exclusively for all remote desktop access.
