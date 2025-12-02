# Remote Desktop Architecture

**Status:** ACTIVE  
**Last Updated:** 2025-12-02  
**Owner:** Infrastructure Team

## Overview

Remote desktop access in the miket-infra-devices environment is provided via **NoMachine**, a high-performance remote desktop solution that operates over the Tailnet mesh network.

## Design Principles

1. **Tailnet-only access** - NoMachine is accessible only via Tailscale, never exposed to the public internet
2. **IaC-managed** - All installation and configuration is via Ansible, no manual steps
3. **Local binary distribution** - NoMachine installers are stored in the repo to avoid unreliable internet downloads

## Architecture

```
┌─────────────────┐     Tailscale Mesh      ┌─────────────────┐
│   Client        │◄───────────────────────►│   Server        │
│   (count-zero)  │     port 4000           │   (atom)        │
│   NoMachine     │                         │   NoMachine     │
│   Client        │                         │   Server        │
└─────────────────┘                         └─────────────────┘
         │                                           │
         │                                           │
    Tailscale IP                              Tailscale IP
    100.108.127.57                            100.120.122.13
```

## Supported Platforms

| Platform | Installer Type | Storage Location |
|----------|---------------|------------------|
| Linux (Fedora) | RPM | `/space/software/nomachine/linux/` |
| macOS | DMG | `/space/software/nomachine/macos/` |
| Windows | EXE | `/space/software/nomachine/windows/` |

## Binary Distribution Pattern

### Why Local Binaries?

NoMachine's download servers block automated/scripted downloads, making reliable IaC deployment impossible. Additionally, downloading large binaries (~80-100MB) over Tailnet from internet sources is unreliable.

**Solution:** Store versioned binaries in `/space/software/nomachine/` on motoko. This follows the filesystem architecture (binaries in `/space`, not in git) and avoids bloating the repository.

### Directory Structure

```
/space/software/nomachine/
├── CHECKSUMS.sha256      # SHA256 checksums for verification
├── README.md             # Binary management documentation
├── linux/
│   └── nomachine_9.2.18_3_x86_64.rpm
├── macos/
│   └── nomachine_9.2.18_1.dmg
└── windows/
    └── nomachine_9.2.18_1_x64.exe
```

**Note:** Binaries are stored on `/space` (motoko's storage) because:
1. GitHub has a 100MB file size limit
2. Git repos shouldn't contain large binaries
3. `/space` is the System of Record for persistent data
4. Ansible runs on motoko and can access `/space` directly

### Update Workflow

When new NoMachine versions are released:

1. **Download** new installers manually from https://www.nomachine.com/download
2. **Verify** downloads are complete (not HTML error pages)
3. **Copy** to motoko's `/space/software/nomachine/<platform>/`
4. **Update checksums**:
   ```bash
   cd /space/software/nomachine
   sha256sum linux/*.rpm macos/*.dmg windows/*.exe > CHECKSUMS.sha256
   ```
5. **Update** `ansible/roles/nomachine_server/defaults/main.yml`:
   - `nomachine_version`
   - `nomachine_*_filename` variables
6. **Commit** config changes: `chore(nomachine): update to version X.Y.Z`
7. **Deploy** to devices: `ansible-playbook playbooks/deploy-nomachine.yml`

## Deployment

### Full Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nomachine.yml
```

### Single Host

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nomachine.yml --limit atom
```

### Via Site Playbook

NoMachine is also included in device site playbooks:

```bash
# Deploy all atom configuration including NoMachine
ansible-playbook -i inventory/hosts.yml playbooks/atom/site.yml --tags nomachine
```

## Security Configuration

### Tailnet-Only Binding

NoMachine is configured to:
- Set `ServerName` to the device's Tailscale FQDN
- Accept connections only from Tailscale CGNAT range (100.64.0.0/10)

### Firewall Rules

Port 4000/tcp is opened in the `trusted` firewall zone (Tailscale interface):

```bash
# Verify firewall rules
firewall-cmd --zone=trusted --list-ports
```

### Authentication

NoMachine uses local system authentication. Users must have:
- A valid local account on the target device
- Credentials for that account

## Connection Guide

### From NoMachine Client

1. Open NoMachine client
2. Click "Add" to create new connection
3. Enter:
   - **Host:** `<hostname>.pangolin-vega.ts.net`
   - **Port:** `4000`
4. Connect and authenticate with local credentials

### Connection String Format

```
nxs://<hostname>.pangolin-vega.ts.net:4000
```

Examples:
- `nxs://atom.pangolin-vega.ts.net:4000`
- `nxs://motoko.pangolin-vega.ts.net:4000`

## Troubleshooting

### Connection Refused

1. Verify NoMachine is running:
   ```bash
   ssh <host> "/usr/NX/bin/nxserver --status"
   ```

2. Verify port is listening:
   ```bash
   ssh <host> "ss -tlnp | grep 4000"
   ```

3. Verify firewall allows traffic:
   ```bash
   ssh <host> "firewall-cmd --zone=trusted --list-ports"
   ```

### Service Not Starting

1. Check service status:
   ```bash
   ssh <host> "systemctl status nxserver"
   ```

2. Check logs:
   ```bash
   ssh <host> "journalctl -u nxserver -n 50"
   ```

3. Restart service:
   ```bash
   ssh <host> "sudo /usr/NX/bin/nxserver --restart"
   ```

### Version Mismatch

If client and server versions are incompatible:

1. Update client to match server version
2. Or update server: `ansible-playbook playbooks/deploy-nomachine.yml --limit <host>`

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 9.2.18 | 2025-12-02 | Initial IaC deployment, local binary pattern |

## Related Documentation

- Ansible Role: `ansible/roles/nomachine_server/`
- Deployment Playbook: `ansible/playbooks/deploy-nomachine.yml`
- Binary Storage: `/space/software/nomachine/`
- Device Inventory: `devices/inventory.yaml`

