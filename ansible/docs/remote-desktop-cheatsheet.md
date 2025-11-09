# Remote Desktop Connection Cheatsheet

Generated: 2025-11-09T00:05:27Z

## Overview

This cheatsheet provides quick connection information for all hosts in the tailnet. All connections use Tailscale MagicDNS and are restricted to the Tailscale network (100.64.0.0/10).

## Connection Methods

### Linux Clients
- **GUI**: `remmina` (Remmina Remote Desktop Client)
- **CLI**: `rdp HOSTNAME` or `xfreerdp /v:HOSTNAME.tail2e55fe.ts.net:3389`
- **Example**: `rdp motoko`

### Windows Clients
- **GUI**: `mstsc` (Remote Desktop Connection)
- **CLI**: `rdp HOSTNAME` or `mstsc /v:HOSTNAME.tail2e55fe.ts.net:3389`
- **Example**: `rdp motoko`

### macOS Clients
- **RDP**: Microsoft Remote Desktop (App Store) or `rdp HOSTNAME`
- **VNC**: Screen Sharing (built-in) or `vnc HOSTNAME`
- **Example**: `rdp motoko` or `vnc motoko`

## Host Connections

### MOTOKO

- **Hostname**: `motoko.tail2e55fe.ts.net` (MagicDNS)
- **Protocol**: RDP
- **Port**: 3389
- **Connection**: `rdp://motoko.tail2e55fe.ts.net:3389`
- **Quick Connect**: `rdp motoko`

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
- **Protocol**: RDP
- **Port**: 3389
- **Connection**: `rdp://count-zero.tail2e55fe.ts.net:3389`
- **Quick Connect**: `rdp count-zero`


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
| motoko | rdp | 3389 | `rdp motoko` |
| wintermute | rdp | 3389 | `rdp wintermute` |
| armitage | rdp | 3389 | `rdp armitage` |
| count-zero | rdp | 3389 | `rdp count-zero` |

