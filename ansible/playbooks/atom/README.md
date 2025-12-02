# Atom Playbooks

Configuration and validation playbooks for the **atom** resilience node.

## Device Overview

| Property | Value |
|----------|-------|
| Hostname | atom |
| Tailscale IP | 100.120.122.13 |
| OS | Fedora Workstation 43 (GNOME) |
| Hardware | Lenovo ThinkPad X1 Carbon (2012) |
| CPU | Intel Core i7-3667U |
| RAM | 8GB |
| Storage | 224GB SSD |
| GPU | Intel HD Graphics 4000 |
| Role | Resilience Node |

## Role: Resilience Node

A resilience node is a battery-backed device that stays alive when power fails to provide:

1. **Network presence proof** - node_exporter metrics prove the network still exists
2. **SSH foothold** - Recovery operations when other servers are down
3. **Alert origin** - Can send notifications that infrastructure is down

## Design Principles

- **Simplicity over features** - Minimal services = fewer failure points
- **Reliability over capability** - If it's not essential, don't run it
- **Boring and bulletproof** - No experimental features

## Playbooks

### `site.yml` - Full Deployment

Applies all resilience node configuration:

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
| prometheus-node-exporter | Metrics | 9100 |
| tailscaled | Tailscale mesh | - |
| firewalld | Firewall | - |

## What atom Does NOT Run

By design, atom does NOT run:

- Container runtime (Podman/Docker)
- AI workloads (no GPU compute capability)
- Storage services (SMB/NFS)
- Development tools beyond basics

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
```

## Coordination with miket-infra

| Managed By | Items |
|------------|-------|
| miket-infra | Ansible inventory entry, host_vars, Tailscale tags, AKV secret |
| miket-infra-devices | Package baseline, power policy, services, firewall |

**Do not duplicate:** Tailscale enrollment, device tags, AKV secrets are in miket-infra.

