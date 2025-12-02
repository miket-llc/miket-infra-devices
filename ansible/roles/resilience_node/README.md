# Resilience Node Role

**Configuration-only role** for battery-backed laptops acting as resilience nodes.

## Purpose

A resilience node is a battery-backed device that stays alive when power fails to provide:

- **Network presence proof** - node_exporter metrics show the network still exists
- **SSH foothold** - Recovery operations when other servers are down
- **Alert origin** - Can send notifications that infrastructure is down

## Design Principles

1. **Simplicity over features** - Minimal services = fewer failure points
2. **Reliability over capability** - If it's not essential for resilience, don't run it
3. **Boring and bulletproof** - No experimental features, no heavy workloads

## What This Role Does

- ✅ Configures power management (never sleep, shutdown at 2% battery)
- ✅ Deploys minimal package baseline
- ✅ Configures node_exporter for Prometheus metrics
- ✅ Sets up firewall for Tailscale
- ✅ Documents SELinux technical debt

## What This Role Does NOT Do

- ❌ Install Tailscale (done via bootstrap)
- ❌ Configure container runtime (not a container host)
- ❌ Change boot target from GNOME (user's choice)
- ❌ Install development tools beyond basics

## Prerequisites

- Fresh Fedora Workstation installation
- Tailscale authenticated (`tailscale up` already performed)
- Battery-backed hardware (laptop)

## Usage

```yaml
- hosts: atom
  roles:
    - resilience_node
```

## Power Management

| Scenario | Behavior |
|----------|----------|
| Lid close on AC | Continue running |
| Lid close on battery | Continue running |
| Idle for extended period | Continue running |
| Battery at 5% | Warning (configurable) |
| Battery at 2% | Graceful shutdown |
| AC power restored | Resume normally |

## Package Baseline

Intentionally minimal:

| Package | Purpose |
|---------|---------|
| vim-minimal | Emergency editing |
| htop | Process monitoring |
| tree | Directory inspection |
| tmux | Session persistence |
| rsync | File transfer |
| curl | HTTP debugging |
| jq | JSON parsing |
| lsof | File descriptor debugging |
| net-tools | Network utilities |
| bind-utils | DNS debugging |

### Intentionally NOT Installed

- **podman/docker** - Not a container host
- **git** - No development workloads
- **gcc/make** - No compilation
- **nvidia drivers** - Intel-only GPU

## SELinux Technical Debt

The `sshd_t` domain is set to permissive mode as a workaround for Tailscale SSH.

**Reason:** Tailscale SSH uses a non-standard mechanism that the default SELinux `sshd_t` policy doesn't anticipate.

**Risk:** Low - Tailscale SSH is the only SSH mechanism, and the device is only accessible via the tailnet.

**Future improvement:** Create a custom SELinux policy module for Tailscale SSH.

To audit AVC denials:
```bash
ausearch -m AVC -ts recent | grep sshd_t
```

## Variables

See `defaults/main.yml` for all configurable variables.

Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `resilience_node_critical_battery_percent` | 2 | Battery % that triggers shutdown |
| `resilience_node_low_battery_warning` | 5 | Battery % that triggers warning |
| `resilience_node_exporter_port` | 9100 | Prometheus node_exporter port |
| `resilience_node_boot_target` | graphical.target | Keeps GNOME |

## Testing Checklist

After deployment, verify:

- [ ] Lid close while on AC → Does NOT sleep
- [ ] Lid close while on battery → Does NOT sleep
- [ ] Idle for extended period → Does NOT sleep
- [ ] `systemctl status prometheus-node-exporter` → Active
- [ ] `curl http://localhost:9100/metrics` → Metrics returned
- [ ] `tailscale status` → Connected
- [ ] SSH accessible via Tailscale

