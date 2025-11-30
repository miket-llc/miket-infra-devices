---
# Copyright (c) 2025 MikeT LLC. All rights reserved.
document_title: Motoko Thermal Management Runbook
author: Codex-CA-001 (Chief Architect)
last_updated: 2025-11-30
status: Published
related_initiatives:
  - initiatives/motoko-headless-operation
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-30-motoko-thermal-management
---

# Motoko Thermal Management Runbook

## Overview

This runbook describes the thermal and fan management system for motoko (Alienware laptop) operating with lid closed. The system provides aggressive cooling to prevent thermal issues in headless operation.

## Context

**Device:** motoko (Alienware m17 R2)  
**Hardware:** Intel Core i9-9980HK (8 cores) + NVIDIA RTX 2080 Max-Q  
**Operation Mode:** Headless server with lid closed  
**Previous Issues:** Thermal problems requiring aggressive fan management

## Architecture

The thermal management system consists of:

1. **thermald** - Linux Thermal Daemon for CPU/system cooling
2. **CPU Thermal Monitor** - Monitors CPU temperatures and writes state files
3. **GPU Thermal Monitor** - Monitors GPU temperatures (from `motoko_ai_profile` role)
4. **Integrated Status** - Combined CPU + GPU thermal reporting

## Thermal Thresholds

### CPU Thresholds (Aggressive for Lid-Closed)
- **Cool:** < 60°C - Normal operation
- **Normal:** 60-70°C - Standard cooling
- **Warm:** 70-80°C - Increased fan speed
- **Hot:** 80-90°C - Aggressive cooling
- **Critical:** > 90°C - Maximum cooling + throttling

### GPU Thresholds (from motoko_ai_profile)
- **Normal:** < 70°C - All models available
- **Hot:** 70-80°C - Reduce load
- **Critical:** > 85°C - Reject GPU requests

## Deployment

### Initial Deployment

```bash
cd ~/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/thermal-management.yml
```

### Verify Deployment

```bash
# Check service status
systemctl status thermald
systemctl status cpu-thermal-monitor

# Check thermal status
/usr/local/bin/thermal-status
```

## Monitoring

### Check Current Temperatures

```bash
# Integrated status (CPU + GPU)
/usr/local/bin/thermal-status

# CPU only
cat /tmp/cpu_thermal_state
cat /tmp/cpu_temperature

# GPU only
cat /tmp/gpu_thermal_state
cat /tmp/gpu_temperature

# Detailed sensors
sensors
```

### Service Status

```bash
# Check thermald
systemctl status thermald
journalctl -u thermald -n 50

# Check CPU monitor
systemctl status cpu-thermal-monitor
journalctl -u cpu-thermal-monitor -n 50
```

## Troubleshooting

### High CPU Temperatures

**Symptoms:**
- CPU temperature > 80°C under load
- System throttling
- Fan noise excessive

**Actions:**
1. Check current temperature:
   ```bash
   /usr/local/bin/thermal-status
   ```

2. Verify thermald is running:
   ```bash
   systemctl status thermald
   ```

3. Check thermald logs:
   ```bash
   journalctl -u thermald -f
   ```

4. Verify thermal configuration:
   ```bash
   cat /etc/thermald/thermal-conf.xml
   ```

5. If thermald not responding, restart:
   ```bash
   sudo systemctl restart thermald
   ```

### High GPU Temperatures

**Symptoms:**
- GPU temperature > 80°C
- GPU requests being rejected

**Actions:**
1. Check GPU status:
   ```bash
   nvidia-smi
   cat /tmp/gpu_thermal_state
   ```

2. Verify GPU power limit:
   ```bash
   nvidia-smi --query-gpu=power.limit --format=csv
   # Should show 70W (capped from 90W)
   ```

3. Check GPU thermal monitor:
   ```bash
   systemctl status gpu-thermal-monitor
   ```

### Services Not Starting

**Symptoms:**
- `thermald` or `cpu-thermal-monitor` not running

**Actions:**
1. Check service status:
   ```bash
   systemctl status thermald
   systemctl status cpu-thermal-monitor
   ```

2. Check logs:
   ```bash
   journalctl -u thermald -n 100
   journalctl -u cpu-thermal-monitor -n 100
   ```

3. Re-run deployment:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/motoko/thermal-management.yml
   ```

## Configuration Files

### thermald Configuration
- **Location:** `/etc/thermald/thermal-conf.xml`
- **Managed by:** Ansible role `motoko_thermal_management`
- **Purpose:** Defines CPU thermal trip points and cooling actions

### Systemd Overrides
- **Location:** `/etc/systemd/system/thermald.service.d/override.conf`
- **Purpose:** Aggressive mode configuration

### Monitoring Scripts
- **CPU Monitor:** `/usr/local/bin/cpu-thermal-monitor`
- **Status Script:** `/usr/local/bin/thermal-status`
- **State Files:** `/tmp/cpu_thermal_state`, `/tmp/cpu_temperature`

## Integration with Other Systems

### GPU Thermal Management
The CPU thermal management works alongside GPU thermal management from `motoko_ai_profile` role:
- GPU monitor: `/tmp/gpu_thermal_state`
- GPU temperature: `/tmp/gpu_temperature`
- Both monitored by integrated status script

### System Health Watchdog
The `monitoring` role's system health watchdog can monitor thermal state files for alerts.

## Maintenance

### Regular Checks

Weekly:
- Review thermal status: `/usr/local/bin/thermal-status`
- Check service logs for errors
- Verify temperatures are within normal ranges

### Updates

When updating thermal management:
1. Test changes with `--check`:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/motoko/thermal-management.yml --check
   ```

2. Apply changes:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/motoko/thermal-management.yml
   ```

3. Verify after update:
   ```bash
   /usr/local/bin/thermal-status
   systemctl status thermald cpu-thermal-monitor
   ```

## Related Documentation

- `ansible/roles/motoko_thermal_management/README.md` - Role documentation
- `ansible/roles/motoko_ai_profile/` - GPU thermal management
- `ansible/roles/fedora_headless_base/` - Lid-closed configuration
- `docs/guides/motoko-ai-profile.md` - AI profile guide

## Emergency Procedures

### Critical Thermal Event

If temperatures exceed critical thresholds:

1. **Immediate Actions:**
   ```bash
   # Check status
   /usr/local/bin/thermal-status
   
   # Stop GPU workloads
   podman stop vllm-embeddings-motoko classifier-motoko
   
   # Check system load
   uptime
   ```

2. **If system is responsive:**
   ```bash
   # Restart thermal services
   sudo systemctl restart thermald
   sudo systemctl restart cpu-thermal-monitor
   ```

3. **If system is unresponsive:**
   - Physical access: Open lid to improve airflow
   - Remote: Reboot via IPMI/WOL if available
   - Last resort: Hard power cycle

## Notes

- This configuration is optimized for **lid-closed operation**
- Aggressive thresholds are intentional to prevent thermal issues
- CPU and GPU thermal management work independently but complement each other
- State files are updated every 10 seconds
- thermald uses passive cooling (CPU frequency scaling) primarily

