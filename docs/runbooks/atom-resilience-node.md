# Atom Resilience Node Runbook

**Status:** ACTIVE  
**Target:** atom (Lenovo ThinkPad X1 Carbon 2012)  
**Owner:** Infrastructure Team  
**Last Updated:** 2025-12-01

## Overview

Atom is a **resilience node** - a battery-backed device that stays alive when power fails to provide:

- **Network presence proof** via Prometheus metrics
- **SSH foothold** for recovery operations  
- **Alert origin** when infrastructure is down

## Design Principles

| Principle | Implementation |
|-----------|----------------|
| Simplicity over features | Minimal services |
| Reliability over capability | Fewer failure points |
| Boring and bulletproof | No experimental features |

## Device Specifications

| Property | Value |
|----------|-------|
| Hostname | atom |
| Tailscale IP | 100.120.122.13 |
| FQDN | atom.pangolin-vega.ts.net |
| OS | Fedora Workstation 43 (GNOME) |
| Hardware | Lenovo ThinkPad X1 Carbon (2012) |
| CPU | Intel Core i7-3667U |
| RAM | 8GB |
| Storage | 224GB SSD |
| GPU | Intel HD Graphics 4000 (integrated) |
| Battery | Yes (implicit UPS) |

## Power Policy

| Event | Behavior | Configuration File |
|-------|----------|-------------------|
| Lid close (AC) | Continue running | `/etc/systemd/logind.conf.d/99-resilience-node.conf` |
| Lid close (battery) | Continue running | `/etc/systemd/logind.conf.d/99-resilience-node.conf` |
| Extended idle | Continue running | `/etc/systemd/logind.conf.d/99-resilience-node.conf` |
| Battery at 5% | Warning | `/etc/UPower/UPower.conf` |
| Battery at 2% | Graceful shutdown | `/etc/UPower/UPower.conf` |
| Power button | Shutdown | `/etc/systemd/logind.conf.d/99-resilience-node.conf` |

### Masked Systemd Targets

```bash
# These targets are masked to prevent suspend/hibernate
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

## Services

| Service | Purpose | Port | Status |
|---------|---------|------|--------|
| prometheus-node-exporter | Prometheus metrics | 9100 | Enabled |
| tailscaled | Tailscale mesh | - | Enabled |
| firewalld | Firewall | - | Enabled |

### What atom Does NOT Run

By design:

- ❌ Container runtime (Podman/Docker)
- ❌ AI workloads (no GPU compute)
- ❌ Storage services (SMB/NFS)
- ❌ Heavy development tools
- ❌ **CIFS mounts to motoko** (removed 2024-12-01, see incident below)

## Network Shares: NONE

**Atom has no CIFS mounts by design.** This is intentional resilience hardening.

### Incident: Desktop Freeze (2024-12-01)

On 2024-12-01, atom's GNOME desktop froze after the CIFS kernel module hit a bug:

1. Network to motoko had a brief hiccup
2. CIFS kernel module (`cfids_invalidation_worker`) tried to invalidate directory cache
3. Kernel bug: "scheduling while atomic" - attempted to sleep while holding a lock
4. Cascaded to dbus failures and systemd-logind errors
5. GNOME Shell froze - mouse moved but UI was unresponsive

**Recovery:** SSH to atom and restart GDM: `sudo systemctl restart gdm`

### Resolution

- Removed all CIFS mounts from atom (playbook: `playbooks/atom/remove-cifs-mounts.yml`)
- Health reporting now uses SSH-based push instead of writing to mounted `/space`
- Core resilience function (node_exporter, SSH) works regardless of motoko status

### Health Reporting

Atom pushes health status via SSH (not dependent on mounts):

```bash
# Timer-based (hourly)
systemctl status resilience-health.timer

# Manual check
/usr/local/bin/resilience_health_check.sh
```

The health check pushes to `motoko:/space/devices/atom/mdt/_status.json` via SSH.
If motoko is unreachable, the push fails silently - **this is expected and correct**.

## Firewall Configuration

```bash
# tailscale0 interface in trusted zone
firewall-cmd --zone=trusted --add-interface=tailscale0 --permanent

# node_exporter port open
firewall-cmd --add-port=9100/tcp --permanent
```

## SELinux Technical Debt

The `sshd_t` domain is in permissive mode for Tailscale SSH:

```bash
# Workaround applied
semanage permissive -a sshd_t
```

**Risk:** Low - device only accessible via tailnet  
**Future:** Create custom policy module if AVC denials cause issues

To audit denials:
```bash
ausearch -m AVC -ts recent | grep sshd_t
```

## Configuration Files

| File | Purpose | Managed By |
|------|---------|------------|
| `/etc/systemd/logind.conf.d/99-resilience-node.conf` | Lid switch, power key | Ansible |
| `/etc/UPower/UPower.conf` | Battery thresholds | Ansible |
| `/etc/dconf/db/local.d/00-power` | GNOME power settings | Ansible |
| `/etc/dconf/db/local.d/locks/power` | Lock GNOME settings | Ansible |
| `/etc/sudoers.d/mdt` | Passwordless sudo | Ansible |

---

## Rebuilding atom from Scratch

### Prerequisites

1. Fresh Fedora Workstation 43 installation
2. Network connectivity
3. Access to miket-infra for Tailscale enrollment key
4. Azure CLI authenticated (for AKV access)

### Step 1: Install Fedora Workstation 43

1. Download Fedora Workstation 43 ISO
2. Create bootable USB
3. Install with:
   - Username: `mdt`
   - Hostname: `atom`
   - Enable automatic login (optional)

### Step 2: Join Tailnet (via miket-infra)

Follow the miket-infra runbook: `docs/runbooks/FEDORA_SERVER_TAILNET_ONBOARDING.md`

```bash
# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Get enrollment key from miket-infra
cd ~/miket-infra/infra/tailscale/entra-prod
terraform output -raw enrollment_key

# 3. Enroll with SSH enabled
sudo tailscale up \
  --auth-key=<ENROLLMENT_KEY> \
  --ssh \
  --accept-dns \
  --accept-routes

# 4. Verify
tailscale status
```

### Step 3: Bootstrap (One-Time)

These steps are done via miket-infra bootstrap script:

```bash
# From miket-infra
./scripts/bootstrap/atom-setup.sh
```

The bootstrap script configures:
- SELinux (sshd_t permissive)
- node_exporter installation
- Firewall basics
- Initial power management

### Step 4: Apply miket-infra-devices Configuration

From the Ansible control node (motoko):

```bash
# Navigate to ansible directory
cd ~/miket-infra-devices/ansible

# Run atom site playbook
ansible-playbook -i inventory/hosts.yml playbooks/atom/site.yml

# Validate configuration
ansible-playbook -i inventory/hosts.yml playbooks/atom/validate-resilience.yml
```

### Step 5: Verify Configuration

```bash
# On atom
# Check power management
cat /etc/systemd/logind.conf.d/99-resilience-node.conf

# Check node_exporter
systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | head

# Check Tailscale
tailscale status

# Check masked targets
systemctl status sleep.target suspend.target hibernate.target

# Check firewall
firewall-cmd --list-all
firewall-cmd --zone=trusted --list-interfaces
```

### Step 6: Manual Power Tests

| Test | Expected Result | ✓ |
|------|-----------------|---|
| Close lid on AC | System continues running | |
| Close lid on battery | System continues running | |
| Leave idle 30+ minutes | System continues running | |
| Reboot | All services start automatically | |
| Hard power cycle | Configuration survives | |

---

## Troubleshooting

### Desktop Frozen (UI Unresponsive)

If the desktop is frozen (mouse moves but can't click anything):

1. **SSH in and restart GDM:**
   ```bash
   ssh atom.pangolin-vega.ts.net
   sudo systemctl restart gdm
   ```

2. **Check what caused it:**
   ```bash
   journalctl -b -1 --priority=err | tail -100
   ```

3. **Look for CIFS/kernel bugs:**
   ```bash
   journalctl -b -1 | grep -E "(cifs|BUG:|scheduling while atomic)"
   ```

If you see CIFS-related kernel bugs, ensure mounts were properly removed:
```bash
mount | grep cifs  # Should return nothing
cat /etc/fstab | grep cifs  # Should return nothing
```

### System Sleeps with Lid Closed

1. Check logind configuration:
   ```bash
   cat /etc/systemd/logind.conf.d/99-resilience-node.conf
   ```

2. Check for other logind configs:
   ```bash
   ls -la /etc/systemd/logind.conf.d/
   ```

3. Restart logind:
   ```bash
   sudo systemctl restart systemd-logind
   ```

4. Verify masked targets:
   ```bash
   systemctl status sleep.target
   ```

### node_exporter Not Running

```bash
# Check service status
systemctl status prometheus-node-exporter

# Check logs
journalctl -u prometheus-node-exporter -n 50

# Restart service
sudo systemctl restart prometheus-node-exporter
```

### Tailscale SSH Not Working

```bash
# Check Tailscale status
tailscale status

# Check SELinux
getenforce
semanage permissive -l | grep sshd_t

# If sshd_t not permissive, apply workaround
sudo semanage permissive -a sshd_t

# Check for AVC denials
ausearch -m AVC -ts recent
```

### Battery Shutdown Not Working

```bash
# Check UPower configuration
cat /etc/UPower/UPower.conf

# Check UPower service
systemctl status upower

# Check battery status
upower -i /org/freedesktop/UPower/devices/battery_BAT0
```

---

## Monitoring

### Prometheus Scrape Target

Add to Prometheus configuration:

```yaml
- targets:
    - atom.pangolin-vega.ts.net:9100
  labels:
    device: atom
    role: resilience
```

### Useful Metrics

| Metric | Purpose |
|--------|---------|
| `node_power_supply_capacity` | Battery percentage |
| `node_power_supply_online` | AC power status |
| `up` | Device availability |
| `node_load1` | System load |

### Alert Suggestions

```yaml
# Alert when atom goes down (resilience node failure)
- alert: ResilienceNodeDown
  expr: up{device="atom"} == 0
  for: 5m
  annotations:
    summary: "Resilience node atom is down"
    description: "Battery-backed resilience node is offline. Check power and network."

# Alert when atom battery is low
- alert: ResilienceNodeBatteryLow
  expr: node_power_supply_capacity{device="atom"} < 20
  for: 10m
  annotations:
    summary: "Resilience node battery low"
    description: "atom battery at {{ $value }}%. Check AC power."
```

---

## Coordination with miket-infra

| Repo | Manages |
|------|---------|
| **miket-infra** | Ansible inventory, host_vars, Tailscale tags, AKV secret (`atom-ansible-password`) |
| **miket-infra-devices** | Package baseline, power policy, services, firewall |

### If You Need Changes in miket-infra

- Tailscale ACL changes → PR to miket-infra
- New AKV secrets → Request via miket-infra
- Inventory/host_vars changes → Coordinate with infra team

---

## Monthly Maintenance

1. [ ] Verify `tailscale status` shows Connected
2. [ ] Verify `curl http://localhost:9100/metrics` returns data
3. [ ] Check battery health: `upower -i /org/freedesktop/UPower/devices/battery_BAT0`
4. [ ] Review `journalctl -p err -b` for errors
5. [ ] Apply system updates: `sudo dnf upgrade --refresh`

---

## Reference

- **Ansible Role:** `ansible/roles/resilience_node/`
- **Site Playbook:** `ansible/playbooks/atom/site.yml`
- **Validation Playbook:** `ansible/playbooks/atom/validate-resilience.yml`
- **Host Vars:** `ansible/inventory/host_vars/atom.yml`
- **Device Inventory:** `devices/inventory.yaml`
- **Prometheus Config:** `tools/monitoring/prometheus.yml`
- **Bootstrap Script:** `miket-infra/scripts/bootstrap/atom-setup.sh`

