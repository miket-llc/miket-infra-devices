# Remote Desktop Playbooks

This directory contains playbooks for managing remote desktop access across the Tailscale tailnet.

## Playbooks

### `remote_detect.yml`
Detects existing remote desktop servers on Linux hosts (primarily Motoko).

**Usage**:
```bash
ansible-playbook playbooks/remote_detect.yml -l motoko --tags remote:detect
```

**What it does**:
- Detects xrdp, x11vnc, TigerVNC, GNOME Remote Desktop, Vino
- Identifies display server (Xorg vs Wayland)
- Detects firewall type (ufw, firewalld, iptables)
- Sets facts for use by other playbooks

### `remote_server.yml`
Configures remote desktop servers per host OS.

**Usage**:
```bash
# All servers
ansible-playbook playbooks/remote_server.yml --tags remote:server

# Linux only
ansible-playbook playbooks/remote_server.yml -l linux_servers --tags remote:server

# Windows only
ansible-playbook playbooks/remote_server.yml -l windows_servers --tags remote:server
```

**What it does**:
- Linux: Installs and configures xrdp
- Windows: Enables RDP with NLA
- macOS: Documents setup instructions
- Configures firewall rules restricted to Tailscale subnet

### `remote_clients.yml`
Installs remote desktop clients on workstations.

**Usage**:
```bash
ansible-playbook playbooks/remote_clients.yml --tags remote:client
```

**What it does**:
- Linux: Installs Remmina and FreeRDP
- Windows: Ensures MSTSC is available
- macOS: Documents client installation and creates helper scripts

### `remote_firewall.yml`
Configures firewall rules for remote desktop access (idempotent).

**Usage**:
```bash
ansible-playbook playbooks/remote_firewall.yml --tags remote:firewall
```

**What it does**:
- Linux: Configures ufw/firewalld/iptables rules restricted to Tailscale subnet
- Windows: Verifies RDP firewall rules (configured by remote_server_windows_rdp)

### `remote_cheatsheet.yml`
Generates a connection cheatsheet from inventory.

**Usage**:
```bash
ansible-playbook playbooks/remote_cheatsheet.yml --tags remote:docs
```

**What it does**:
- Generates `docs/remote-desktop-cheatsheet.md` with connection information for all hosts

## Tags

All playbooks support these tags:

- `remote` - All remote desktop tasks
- `remote:detect` - Detection tasks only
- `remote:server` - Server configuration only
- `remote:client` - Client installation only
- `remote:firewall` - Firewall configuration only
- `remote:docs` - Documentation generation only

## Complete Setup Workflow

```bash
cd ansible

# 1. Detect existing servers
ansible-playbook playbooks/remote_detect.yml -l motoko --tags remote:detect

# 2. Configure servers
ansible-playbook playbooks/remote_server.yml --tags remote:server

# 3. Install clients
ansible-playbook playbooks/remote_clients.yml --tags remote:client

# 4. Configure firewall (idempotent, safe to run multiple times)
ansible-playbook playbooks/remote_firewall.yml --tags remote:firewall

# 5. Generate cheatsheet
ansible-playbook playbooks/remote_cheatsheet.yml --tags remote:docs
```

## Roles

See `ansible/roles/remote_*` for role documentation:
- `remote_detect_linux` - Detection role
- `remote_server_linux_xrdp` - Linux RDP server
- `remote_server_windows_rdp` - Windows RDP server
- `remote_client_linux` - Linux clients
- `remote_client_windows` - Windows clients
- `remote_client_macos` - macOS clients
- `remote_firewall` - Firewall configuration

## See Also

- Main README: `README.md` (Tailnet Remote Desktop section)
- Migration guide: `docs/remote-desktop-migration.md`
- Generated cheatsheet: `docs/remote-desktop-cheatsheet.md`

