# Remote Desktop Connection Cheatsheet

Generated: 2025-11-09T00:05:27Z

## Overview

This cheatsheet provides quick connection information for all hosts in the tailnet. All connections use Tailscale MagicDNS and are restricted to the Tailscale network (100.64.0.0/10).

## Connection Methods

### Linux Clients
- **RDP**: `remmina` GUI or `rdp HOSTNAME`
- **VNC**: `remmina` GUI or `vnc HOSTNAME`
- **Examples**: `rdp wintermute`, `vnc motoko`

### Windows Clients
- **RDP**: `mstsc /v:HOSTNAME.tail2e55fe.ts.net:3389`
- **VNC**: RealVNC, TightVNC, or `vnc HOSTNAME`
- **Examples**: `mstsc /v:wintermute.tail2e55fe.ts.net`, `vnc motoko`

### macOS Clients
- **RDP**: Microsoft Remote Desktop or `rdp HOSTNAME`
- **VNC**: Screen Sharing (`Cmd+K` → `vnc://HOSTNAME.tail2e55fe.ts.net`)
- **Examples**: `rdp armitage`, `vnc count-zero`

## Host Connections

### MOTOKO

- **Hostname**: `motoko.tail2e55fe.ts.net` (MagicDNS)
- **Protocol**: VNC
- **Port**: 5900
- **Connection**: `vnc://motoko.tail2e55fe.ts.net:5900`
- **Quick Connect**: `vnc motoko`
- **Desktop Environment**: GNOME
- **Display Server**: Xorg

### WINTERMUTE

- **Hostname**: `wintermute.tail2e55fe.ts.net` (MagicDNS)
- **Protocol**: RDP
- **Port**: 3389
- **Connection**: `rdp://wintermute.tail2e55fe.ts.net:3389`
- **Quick Connect**: `rdp wintermute`

### ARMITAGE

- **Hostname**: `armitage.tail2e55fe.ts.net` (MagicDNS)
- **Protocol**: RDP
- **Port**: 3389
- **Connection**: `rdp://armitage.tail2e55fe.ts.net:3389`
- **Quick Connect**: `rdp armitage`

### COUNT-ZERO

- **Hostname**: `count-zero.tail2e55fe.ts.net` (MagicDNS)
- **Protocol**: VNC
- **Port**: 5900
- **Connection**: `vnc://count-zero.tail2e55fe.ts.net:5900`
- **Quick Connect**: `vnc count-zero`


## Troubleshooting

### Connection Issues

1. **Verify Tailscale connectivity**:
   ```bash
   ping HOSTNAME.tail2e55fe.ts.net
   ```

2. **Check firewall rules**:
   - Linux: `sudo ufw status` or `sudo firewall-cmd --list-all`
   - Windows: `Get-NetFirewallRule -Name "*RDP*"`

3. **Verify service is running**:
   - Linux: `systemctl status xrdp`
   - Windows: `Get-Service TermService`

### Wayland Issues (Linux)

If you're on Wayland and RDP doesn't work:
1. Switch to Xorg session at login
2. Or configure xorgxrdp for Wayland compatibility
3. See README for detailed instructions

### Blank Screen Fixes

- Ensure desktop environment is running
- Check xrdp logs: `sudo journalctl -u xrdp -n 50`
- Verify Xorg session is configured: `/usr/share/xsessions/Xorg.desktop`

### Firewall Checks

- **Linux**: Ensure port 3389 (or configured port) is open on Tailscale interface
- **Windows**: Verify RDP firewall rule allows Tailscale subnet (100.64.0.0/10)

## Security Notes

- All connections are restricted to Tailscale network (100.64.0.0/10)
- No public ports are exposed
- **MagicDNS**: Use `.tail2e55fe.ts.net` hostnames for automatic resolution
- Network Level Authentication (NLA) enabled on Windows hosts

## Quick Reference

| Host | Protocol | Port | Command |
|------|----------|------|---------|
| motoko | vnc | 5900 | `vnc motoko` |
| wintermute | rdp | 3389 | `rdp wintermute` |
| armitage | rdp | 3389 | `rdp armitage` |
| count-zero | vnc | 5900 | `vnc count-zero` |

