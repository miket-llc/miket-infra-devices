# Atom Playbooks

Configuration and management playbooks for **atom** - a headless Fedora server and battery-backed resilience node.

## Device Overview

| Property | Value |
|----------|-------|
| Hostname | atom |
| Tailscale IP | 100.120.122.13 |
| OS | Fedora Server 43 (Headless) |
| Hardware | Lenovo ThinkPad X1 Carbon (2012) |
| CPU | Intel Core i7-3667U |
| RAM | 8GB |
| Storage | 224GB SSD |
| GPU | Intel HD Graphics 4000 (unused) |
| Role | Headless Resilience/Lab Node |
| Boot Target | multi-user.target |

## Role: Headless Resilience Node

A resilience node is a battery-backed device that stays alive when power fails to provide:

1. **Network presence proof** - node_exporter metrics prove the network still exists
2. **SSH foothold** - Recovery operations when other servers are down
3. **Alert origin** - Can send notifications that infrastructure is down
4. **Lab/automation** - Testing and experimentation node

### Headless Operation

As of December 2025, atom runs as a **headless server** with:
- No desktop environment (GNOME removed)
- Boot target: `multi-user.target`
- Access: SSH via Tailscale only
- No remote desktop (NoMachine removed)

## Design Principles

- **Simplicity over features** - Minimal services = fewer failure points
- **Reliability over capability** - If it's not essential, don't run it
- **Boring and bulletproof** - No experimental features
- **Zero external dependencies** - No mounts to other servers
- **100% IaC/CaC** - No manual commands on the device

## Playbooks

### `convert-to-headless.yml` - Headless Conversion ⚠️

**THE ONLY APPROVED PATHWAY** to convert atom to headless. No manual on-box changes permitted.

#### Safe Cutover (Recommended)

First, run with safe cutover to verify connectivity:

```bash
# Step 1: Configure Tailscale and boot target, but KEEP GUI
ansible-playbook playbooks/atom/convert-to-headless.yml --tags safe_headless_cutover

# Step 2: Verify SSH works via Tailscale
ssh atom.pangolin-vega.ts.net

# Step 3: Complete conversion (remove GUI packages)
ansible-playbook playbooks/atom/convert-to-headless.yml
```

#### One-Shot Conversion (Confident Mode)

```bash
ansible-playbook playbooks/atom/convert-to-headless.yml
```

### `site.yml` - Resilience Node Configuration

Applies resilience node configuration (power management, monitoring, etc.):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/atom/site.yml
```

Tags available:
- `power` - Power management configuration
- `monitoring` - node_exporter setup
- `firewall` - Firewall configuration
- `selinux` - SELinux workarounds
- `tailscale` - Tailscale verification

### `validate-resilience.yml` - Validation

Validates all configuration is correctly applied:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/atom/validate-resilience.yml
```

### `remove-cifs-mounts.yml` - Mount Removal

Removes any CIFS/SMB mounts (resilience nodes should have zero external dependencies):

```bash
ansible-playbook -i inventory/hosts.yml playbooks/atom/remove-cifs-mounts.yml
```

## Recovery Procedures

### If You Lose SSH Access

1. **Physical console access**
   - Connect monitor and keyboard directly to atom
   - Login at TTY console (if credentials work)

2. **Re-enable graphical desktop (if needed)**
   ```bash
   sudo systemctl set-default graphical.target
   sudo systemctl unmask gdm
   sudo dnf install @gnome-desktop
   sudo systemctl reboot
   ```

3. **Recovery via Live USB**
   - Boot from Fedora Live USB
   - Mount atom's root filesystem
   - Chroot and fix configuration

### Re-enable Graphical Target via Ansible

If SSH still works but you need to restore graphical boot temporarily:

```bash
# Create a one-off recovery playbook or run ad-hoc:
ansible atom -m command -a "systemctl set-default graphical.target" -b
ansible atom -m command -a "systemctl unmask gdm" -b
ansible atom -m dnf -a "name=@gnome-desktop state=present" -b
ansible atom -m reboot -b
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

Minimal by design:

| Service | Purpose | Port |
|---------|---------|------|
| sshd | SSH access | 22 |
| prometheus-node-exporter | Metrics | 9100 |
| tailscaled | Tailscale mesh | - |
| firewalld | Firewall | - |

## What atom Does NOT Run

By design, atom does NOT run:

- ❌ Desktop environment (GNOME/KDE/X11)
- ❌ Display manager (GDM/SDDM)
- ❌ Container runtime (Podman/Docker)
- ❌ AI workloads (no GPU compute capability)
- ❌ Storage services (SMB/NFS mounts)
- ❌ Remote desktop (NoMachine)
- ❌ GUI development tools

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

