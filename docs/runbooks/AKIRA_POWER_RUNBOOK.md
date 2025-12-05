# Akira Power Resilience Runbook

**Status:** Active  
**Last Updated:** 2025-12-05  
**Author:** Codex-SRE-005  

## Overview

This runbook documents the power resilience architecture for akira, enabling:
1. **Survive power loss** - UPS → graceful shutdown → auto-power-on
2. **Remote power control** - Wake from fully-off state while away
3. **Hard recovery** - Power cycle a hung system remotely

All management is via Tailscale (no direct internet exposure).

## Quick Reference

### Wake akira from powered-off state

```bash
# From any tailnet device, SSH to motoko and wake akira
tailscale ssh mdt@motoko '/usr/local/bin/wake akira'

# Or directly
tailscale ssh mdt@motoko '/usr/local/bin/wake-akira.sh'

# Verify it's coming up
tailscale ping akira
```

### Check if akira is online

```bash
tailscale status | grep akira
# or
tailscale ping akira
```

---

## 1. Hardware Configuration

### 1.1 Network Interfaces (WOL-capable)

| Interface | MAC Address | IP | Purpose |
|-----------|-------------|-----|---------|
| `enp196s0` | `38:05:25:30:42:84` | 192.168.1.184 | Primary (WOL target) |
| `enp197s0` | `38:05:25:30:42:85` | 192.168.1.195 | Secondary |

**WOL Support:** Both NICs support `pumbg` (magic packet).

### 1.2 Power Stack (Current)

| Component | Status | Notes |
|-----------|--------|-------|
| Wake-on-LAN | ✅ Configured | Via motoko relay |
| BMC/IPMI | ❌ N/A | Consumer Strix Point, no dedicated BMC |
| Switched PDU | ❌ TODO | Acquire for out-of-band power control |
| UPS | ❌ TODO | Connect for power loss protection |

### 1.3 WOL Relay Host

**motoko** serves as the always-on WOL relay:
- Same LAN segment as akira (192.168.1.x)
- Tailscale connected
- Can send WOL magic packets

---

## 2. BIOS Configuration Baseline

> ⚠️ **IMPORTANT:** These settings must be configured manually in BIOS.
> Document any changes here as this file IS the configuration record.

### 2.1 Required Settings

| Setting | Value | Location | Why |
|---------|-------|----------|-----|
| **AC Power Loss** | `Power On` | Power Management | Auto-start after power restore |
| **ErP Ready** | `Disabled` | Power Management | Keep +5V standby for WOL |
| **Wake on LAN** | `Enabled` | Network/Power | Allow WOL from S4/S5 |
| **Wake on PCIe** | `Enabled` | Power Management | Wake from PCIe devices |

### 2.2 Verification

After changing BIOS settings:
1. Shut down akira from OS: `sudo poweroff`
2. From motoko: `/usr/local/bin/wake-akira.sh`
3. Verify akira powers on and boots

### 2.3 BIOS Change Log

| Date | Setting | Old Value | New Value | Reason |
|------|---------|-----------|-----------|--------|
| 2025-12-05 | Initial | - | - | Document baseline |

---

## 3. OS Configuration

### 3.1 WOL Service

WOL is enabled via systemd service (`wol@.service`):

```bash
# Check WOL status
sudo ethtool enp196s0 | grep Wake-on
# Should show: Wake-on: g

# Service status
systemctl status wol@enp196s0.service
```

**Managed by:** `ansible/roles/power_wol`

### 3.2 Apply WOL Configuration

```bash
# From motoko (Ansible control node)
cd ~/dev/miket-infra-devices
ansible-playbook -i inventory/hosts.yml ansible/playbooks/configure-akira-power.yml
```

---

## 4. Remote Wake Procedures

### 4.1 Normal Wake (from any tailnet device)

```bash
# SSH to motoko and wake akira
tailscale ssh mdt@motoko '/usr/local/bin/wake akira'

# Wait ~30 seconds, then verify
tailscale ping akira
ssh akira
```

### 4.2 If WOL Fails

1. **Check motoko can reach akira's LAN:**
   ```bash
   tailscale ssh mdt@motoko 'ping -c 2 192.168.1.184'
   ```

2. **Try alternate NIC:**
   ```bash
   tailscale ssh mdt@motoko 'wol 38:05:25:30:42:85'  # enp197s0
   ```

3. **Check BIOS settings** (requires physical access):
   - Verify "AC Power Loss" = Power On
   - Verify "ErP Ready" = Disabled
   - Verify "Wake on LAN" = Enabled

### 4.3 If System is Hung (future: PDU)

When switched PDU is installed:
```bash
# Power cycle via PDU (outlet 3)
# TODO: Add PDU commands when hardware acquired
```

---

## 5. Power Loss Recovery

### 5.1 Expected Behavior

1. **Power fails:** UPS takes over (when installed)
2. **UPS battery low:** NUT triggers graceful shutdown
3. **Power restored:** BIOS "Power On after AC loss" boots akira
4. **Akira boots:** Tailscale reconnects, services start

### 5.2 UPS Configuration (TODO)

When UPS is connected:
```yaml
# devices/akira/config.yml
ups:
  enabled: true
  model: "CyberPower CP1500PFCLCD"
  connection: usb
  daemon: nut
  policy:
    on_battery_low: shutdown
    shutdown_delay_seconds: 120
```

---

## 6. Monitoring & Alerts

### 6.1 Tailscale Status

```bash
# Check if akira is online
tailscale status | grep akira

# From monitoring host
tailscale ping akira --timeout 10s
```

### 6.2 Integration with Netdata (TODO)

Add alert for akira offline > 5 minutes during expected uptime.

---

## 7. Troubleshooting

### WOL packet sent but akira doesn't wake

| Check | Command | Expected |
|-------|---------|----------|
| NIC WOL enabled | `ethtool enp196s0 \| grep Wake-on` | `Wake-on: g` |
| BIOS ErP disabled | Physical BIOS check | ErP = Disabled |
| BIOS WOL enabled | Physical BIOS check | WOL = Enabled |
| Same LAN segment | `ping 192.168.1.184` from motoko | Responds (when on) |

### akira powers on but doesn't boot

1. Check BIOS POST (requires monitor/BMC)
2. Check boot drive order in BIOS
3. Check for kernel panic (serial console if available)

### akira boots but Tailscale doesn't connect

```bash
# If you have local network access
ssh -o ConnectTimeout=5 mdt@192.168.1.184 'tailscale status; systemctl status tailscaled'
```

---

## 8. Hardware Acquisition List

| Item | Purpose | Priority | Notes |
|------|---------|----------|-------|
| Switched PDU | Out-of-band power control | High | CyberPower PDU41001 or similar |
| UPS | Power loss protection | High | CP1500PFCLCD or similar, USB |
| Serial console cable | Debug without monitor | Low | USB-to-serial if needed |

---

## 9. Related Files

- `devices/akira/config.yml` - Power configuration section
- `ansible/roles/power_wol/` - WOL enablement role
- `ansible/roles/power_wol_relay/` - Relay host configuration
- `ansible/host_vars/akira.yml` - Host-specific variables
- `ansible/host_vars/motoko.yml` - Relay host variables

---

## 10. Test Matrix

Run before relying on remote power control:

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Local WOL | Shutdown akira, WOL from motoko | Powers on |
| Tailnet WOL | Shutdown akira, WOL from phone/laptop on tailnet | Powers on |
| AC Power Loss | Unplug akira, plug back in | Auto powers on |
| UPS Shutdown | Pull UPS input (when installed) | Graceful shutdown |
| UPS Recovery | Restore UPS input | Auto powers on |

