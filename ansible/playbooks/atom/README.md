# Atom Playbooks

Configuration and management playbooks for **atom** - a field hacker workstation and basecamp node.

## Device Overview

| Property | Value |
|----------|-------|
| Hostname | atom |
| Tailscale IP | 100.120.122.13 |
| OS | Fedora Server 43 (Sway) |
| Hardware | Lenovo ThinkPad X1 Carbon (2012) |
| CPU | Intel Core i7-3667U |
| RAM | 8GB |
| Storage | 224GB SSD |
| GPU | Intel HD Graphics 4000 |
| Role | Field Hacker Workstation (Basecamp) |
| Boot Target | graphical.target |
| Desktop | Sway (Wayland tiling compositor) |

## Role: Field Hacker Workstation

A basecamp node is a portable, battery-backed workstation optimized for:

1. **SDR/RF Analysis** - RTL-SDR, gqrx, gnuradio
2. **LoRa Development** - Packet sniffing and device hacking
3. **Network Analysis** - wireshark, nmap, aircrack-ng
4. **Serial/Embedded** - USB-to-serial for hardware hacking
5. **Portable Pi-hole** - Local DNS filtering in the field

### Why ThinkPad X1 Carbon?

- **TrackPoint nub**: Precise control without leaving home row
- **Legendary keyboard**: Essential for extended field sessions
- **Battery-backed**: Hours of operation without wall power
- **Lightweight**: Easy to carry in the field
- **Robust**: Survives real-world conditions

### Sway Desktop

As of December 2025, atom runs **Sway** (Wayland tiling compositor):
- Keyboard-driven workflow (perfect for ThinkPad)
- Low resource usage (maximize battery life)
- Boot target: `graphical.target`
- Display manager: greetd

## Design Principles

- **Lightweight over features** - Sway, not KDE/GNOME
- **Battery life priority** - Minimal services, efficient compositor
- **Zero network dependencies** - Works offline/airgapped
- **Keyboard-centric** - Optimized for ThinkPad keyboard + TrackPoint
- **100% IaC/CaC** - No manual commands on the device

## Playbooks

### `site.yml` - Basecamp Node Configuration

Applies basecamp configuration (Sway, power management, hacker tools):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/atom/site.yml
```

Tags available:
- `power` - Power management configuration
- `monitoring` - node_exporter setup
- `firewall` - Firewall configuration
- `sway` - Sway/Wayland configuration
- `tools` - Hacker tools installation

### `validate-resilience.yml` - Validation

Validates all configuration is correctly applied:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/atom/validate-resilience.yml
```

### `remove-cifs-mounts.yml` - Mount Removal

Removes any CIFS/SMB mounts (basecamp nodes should work offline):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/atom/remove-cifs-mounts.yml
```

## Power Policy

| Event | Behavior |
|-------|----------|
| Lid close (AC) | Continue running |
| Lid close (battery) | Continue running |
| Extended idle | Continue running |
| Battery at 5% | Warning |
| Battery at 2% | Graceful shutdown |
| Power button | Shutdown |

## Services

| Service | Purpose | Port |
|---------|---------|------|
| sshd | SSH access | 22 |
| prometheus-node-exporter | Metrics | 9100 |
| tailscaled | Tailscale mesh | - |
| firewalld | Firewall | - |
| greetd | Display manager | - |

## What atom DOES Run

- ✅ Sway (Wayland tiling compositor)
- ✅ SDR tools (rtl-sdr, gqrx)
- ✅ Network tools (wireshark-cli, nmap)
- ✅ Lightweight terminal apps

## What atom Does NOT Run

By design, atom does NOT run:

- ❌ Heavy desktop environments (GNOME/KDE)
- ❌ Container runtime (Podman/Docker)
- ❌ AI workloads (no GPU compute capability)
- ❌ Storage services (SMB/NFS mounts)
- ❌ Remote desktop (NoMachine)
- ❌ Heavy GUI apps (VS Code, SDRangel)

## Firewall Configuration

| Zone | Services | Description |
|------|----------|-------------|
| public | none | Default zone, no services exposed |
| tailnet | ssh, node-exporter | Tailnet-only access (100.64.0.0/10) |

SSH is **ONLY** accessible via Tailscale. No LAN SSH.

## SELinux Note

The `sshd_t` domain is set to permissive mode to allow Tailscale SSH to function. This is documented technical debt:

- **Risk:** Low - device only accessible via tailnet
- **Future:** Create custom policy module if AVC denials cause issues

## Monitoring

Atom exposes Prometheus metrics at `http://atom.pangolin-vega.ts.net:9100/metrics`.

Add to Prometheus scrape targets:
```yaml
- targets:
    - atom.pangolin-vega.ts.net:9100
  labels:
    device: atom
    role: resilience
    headless: "true"
```

## Coordination with miket-infra

| Managed By | Items |
|------------|-------|
| miket-infra | Tailscale ACL tags (`tag:lab-server`, `tag:headless`), AKV secrets |
| miket-infra-devices | Package baseline, power policy, services, firewall, headless conversion |

**Preconditions from miket-infra:**
- Tailscale ACLs include `tag:lab-server` and `tag:headless`
- AKV secret `tailscale-auth-key-atom` exists in `kv-miket-ops`
- Initial auth key tags are `tag:server,tag:linux`

