# Motoko Thermal Management Role

## Overview

This role provides aggressive thermal and fan management for motoko (Alienware laptop) operating with lid closed. It complements the GPU thermal monitoring from `motoko_ai_profile` role by adding CPU/system thermal management.

## Purpose

Motoko is an Alienware laptop repurposed as a headless server. With the lid closed, thermal management becomes critical. This role:

- Configures `thermald` (Linux Thermal Daemon) for aggressive CPU cooling
- Monitors CPU/system temperatures alongside GPU temperatures
- Provides integrated thermal status reporting
- Ensures proper fan operation for lid-closed operation

## Configuration

### Defaults

- **CPU Thermal Thresholds:**
  - Normal: < 60°C
  - Warm: 60-70°C
  - Hot: 70-80°C
  - Critical: > 80°C

- **Monitoring Interval:** 10 seconds

- **Aggressive Mode:** Enabled (optimized for lid-closed operation)

## Usage

### Deploy via Playbook

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/motoko/thermal-management.yml
```

### Check Thermal Status

```bash
/usr/local/bin/thermal-status
```

### Monitor Files

- `/tmp/cpu_thermal_state` - CPU thermal state (cool/normal/warm/hot/critical)
- `/tmp/cpu_temperature` - Current CPU temperature in °C
- `/tmp/gpu_thermal_state` - GPU thermal state (from motoko_ai_profile)
- `/tmp/gpu_temperature` - Current GPU temperature in °C

## Integration

This role works alongside:
- `motoko_ai_profile` role (GPU thermal monitoring)
- `fedora_headless_base` role (lid-closed configuration)

## Services

- `thermald` - Linux Thermal Daemon (CPU cooling)
- `cpu-thermal-monitor` - CPU temperature monitoring service

## Dependencies

- `thermald` package
- `lm-sensors` package
- `sensors-detect` (auto-detects hardware sensors)

## Related Documentation

- `docs/runbooks/motoko-thermal-management.md` - Operational runbook
- `ansible/roles/motoko_ai_profile/` - GPU thermal management

