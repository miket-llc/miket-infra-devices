# Remote Desktop Migration Notes

## Overview

This document provides migration guidance if Motoko currently runs a VNC server and you want to migrate to xrdp (RDP), or if you need to revert back to VNC.

## Detection

Before migrating, run the detection playbook to identify existing remote desktop servers:

```bash
cd ansible
ansible-playbook playbooks/remote_detect.yml -l motoko --tags remote:detect
```

This will show:
- Current VNC servers (x11vnc, TigerVNC, GNOME Remote Desktop, Vino)
- xrdp status (if already installed)
- Display server (Xorg vs Wayland)
- Firewall type

## Migration: VNC → RDP (xrdp)

### Step 1: Install xrdp

The server playbook will install xrdp alongside your existing VNC server:

```bash
ansible-playbook playbooks/remote_server.yml -l motoko --tags remote:server
```

**Note**: Both VNC and RDP can coexist on different ports:
- VNC: Port 5900 (or configured port)
- RDP: Port 3389

### Step 2: Verify RDP Works

Test the connection:

```bash
# From a Linux client
xfreerdp /v:motoko.tailnet.local:3389 /u:mdt /cert-ignore

# Or use the helper script
rdp motoko
```

### Step 3: Stop VNC (Optional)

If you want to migrate completely to RDP, stop the VNC service:

```bash
# On Motoko
sudo systemctl stop x11vnc  # or tigervnc, vino, gnome-remote-desktop
sudo systemctl disable x11vnc
```

**Or keep both**: You can keep VNC running for compatibility and use RDP as the primary protocol.

### Step 4: Configure Firewall

Ensure firewall rules are configured:

```bash
ansible-playbook playbooks/remote_firewall.yml -l motoko --tags remote:firewall
```

## Reversion: RDP → VNC

If you need to revert back to VNC:

### Step 1: Stop xrdp Services

```bash
# On Motoko
sudo systemctl stop xrdp xrdp-sesman
sudo systemctl disable xrdp xrdp-sesman
```

### Step 2: Restart VNC Server

Restart your preferred VNC server:

```bash
# For x11vnc
sudo systemctl start x11vnc
sudo systemctl enable x11vnc

# For TigerVNC
sudo systemctl start tigervnc@:1
sudo systemctl enable tigervnc@:1

# For GNOME Remote Desktop
systemctl --user start gnome-remote-desktop.service
systemctl --user enable gnome-remote-desktop.service
```

### Step 3: Update Firewall (if needed)

If your VNC server uses a different port, update firewall rules:

```bash
# For UFW
sudo ufw allow 5900/tcp from 100.64.0.0/10

# For firewalld
sudo firewall-cmd --permanent --add-port=5900/tcp --source=100.64.0.0/10
sudo firewall-cmd --reload
```

### Step 4: Update Host Variables

Update `ansible/host_vars/motoko.yml`:

```yaml
remote_protocol: vnc
remote_port: 5900
```

## Coexistence

You can run both VNC and RDP simultaneously:

- **VNC**: Port 5900 (or configured)
- **RDP**: Port 3389

Clients can connect to either protocol as needed. This is useful for:
- Compatibility with older clients
- Different use cases (VNC for screen sharing, RDP for remote desktop)
- Gradual migration

## Troubleshooting

### xrdp Shows Blank Screen

1. **Check display server**: Ensure you're using Xorg, not Wayland
   ```bash
   echo $XDG_SESSION_TYPE
   ```

2. **Verify Xorg session**: Check that Xorg session file exists
   ```bash
   ls /usr/share/xsessions/Xorg.desktop
   ```

3. **Check xrdp logs**:
   ```bash
   sudo journalctl -u xrdp -n 50
   sudo journalctl -u xrdp-sesman -n 50
   ```

4. **Restart xrdp**:
   ```bash
   sudo systemctl restart xrdp xrdp-sesman
   ```

### VNC Connection Issues After Migration

1. **Verify VNC service is running**:
   ```bash
   systemctl status x11vnc  # or your VNC service
   ```

2. **Check firewall**:
   ```bash
   sudo ufw status | grep 5900
   ```

3. **Verify port**:
   ```bash
   sudo netstat -tlnp | grep 5900
   ```

## Service Management

### xrdp Services

- `xrdp` - Main RDP daemon (port 3389)
- `xrdp-sesman` - Session manager

### Common VNC Services

- `x11vnc` - Standalone VNC server
- `tigervnc@:DISPLAY` - TigerVNC per-display service
- `gnome-remote-desktop` - GNOME's built-in VNC
- `vino-server` - GNOME Vino VNC server

## Notes

- **No data loss**: Migration only changes remote access protocol, not system configuration
- **Idempotent**: Playbooks can be run multiple times safely
- **Rollback**: Easy to revert by stopping one service and starting another
- **Security**: Both protocols restricted to Tailscale subnet (100.64.0.0/10)

