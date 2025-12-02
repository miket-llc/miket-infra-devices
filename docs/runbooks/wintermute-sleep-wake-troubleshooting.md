# Wintermute Sleep/Wake Troubleshooting Runbook

**Status:** ACTIVE  
**Target:** wintermute (Windows 11 Pro Desktop)  
**Owner:** Infrastructure Team  
**Last Updated:** 2025-01-XX

## Overview

This runbook helps diagnose and resolve sleep/wake issues on wintermute, where the system appears to be sleeping but won't wake up, requiring a power button press to restart.

## Symptoms

- System appears to be in sleep mode (fans quiet, no display)
- System does not respond to keyboard/mouse input
- System does not respond to Wake-on-LAN packets
- Power button press causes system to power off (not wake)
- System requires hard reboot to recover

## Quick Diagnostic

Run the automated diagnostic script on wintermute:

```powershell
# On wintermute (as Administrator)
cd C:\Users\$env:USERNAME\dev\miket-infra-devices
.\devices\wintermute\scripts\Diagnose-SleepWake.ps1
```

This script checks:
- Windows Event Logs for sleep/wake events
- Power management settings
- GPU driver status
- USB device wake settings
- Docker/WSL2 status
- System uptime

## Common Causes

### 1. GPU Driver Issues (Most Common)

**Symptom:** NVIDIA GPU prevents system wake from sleep

**Diagnosis:**
```powershell
# Check GPU driver version
nvidia-smi

# Check for GPU-related errors in Event Viewer
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'nvlddmkm'  # NVIDIA driver
    Level = 2,3  # Error, Warning
} | Where-Object { $_.TimeCreated -gt (Get-Date).AddHours(24) }
```

**Fix:**
1. Update NVIDIA drivers to latest version
2. If issue persists, try disabling "Fast Startup" in Windows Power Options
3. Check NVIDIA Control Panel > Manage 3D Settings > Power Management Mode

### 2. USB Devices Preventing Wake

**Symptom:** USB devices configured to wake system but failing

**Diagnosis:**
```powershell
# List USB devices
Get-PnpDevice | Where-Object { $_.Class -eq 'USB' } | 
    Select-Object FriendlyName, InstanceId, Status

# Check wake settings (requires Device Manager GUI)
# Device Manager > USB devices > Properties > Power Management
```

**Fix:**
1. Open Device Manager
2. Expand "Universal Serial Bus controllers"
3. For each USB device:
   - Right-click > Properties > Power Management
   - Uncheck "Allow this device to wake the computer" (unless needed)
4. Common culprits: USB hubs, external drives, gaming peripherals

### 3. Fast Startup Enabled

**Symptom:** System appears to sleep but actually hibernates, causing wake issues

**Diagnosis:**
```powershell
# Check Fast Startup status
powercfg /query SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION
```

**Fix:**
1. Control Panel > Power Options > Choose what the power buttons do
2. Click "Change settings that are currently unavailable"
3. Uncheck "Turn on fast startup (recommended)"
4. Save changes and reboot

### 4. Docker/WSL2 Interference

**Symptom:** Docker containers or WSL2 prevent proper sleep

**Diagnosis:**
```powershell
# Check Docker status
Get-Service com.docker.service
docker ps

# Check WSL2 status
wsl --list --verbose
```

**Fix:**
1. Stop Docker containers before sleep:
   ```powershell
   docker stop vllm-wintermute
   ```
2. Shutdown WSL2 if not needed:
   ```powershell
   wsl --shutdown
   ```
3. Consider disabling Docker Desktop auto-start if sleep issues persist

### 5. Power Supply Issues

**Symptom:** System loses power during sleep transition

**Diagnosis:**
- Check Windows Event Logs for unexpected shutdowns
- Look for Event ID 6008 (unexpected shutdown)
- Check PSU capacity vs system load

**Fix:**
- Verify PSU is adequate for system (RTX 4070 Super requires 650W+)
- Check PSU connections
- Test with different PSU if available

## Detailed Event Log Analysis

### Check Sleep/Wake Events

```powershell
# Get all power-related events from last 24 hours
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-Kernel-Power'
    StartTime = (Get-Date).AddHours(-24)
} | Format-List TimeCreated, Id, LevelDisplayName, Message
```

### Key Event IDs

| Event ID | Meaning |
|----------|---------|
| 42 | System entering sleep (S1-S4) |
| 107 | System resuming from sleep |
| 109 | System entering hibernate (S4) |
| 131 | System resuming from hibernate |
| 506-600 | Various power transition events |
| 6008 | Unexpected shutdown |

### Check for Errors

```powershell
# Get power-related errors
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-Kernel-Power'
    Level = 2,3  # Error, Warning
    StartTime = (Get-Date).AddHours(-24)
} | Format-List TimeCreated, Id, Message
```

## Power Settings Configuration

### Check Current Settings

```powershell
# Active power plan
powercfg /getactivescheme

# Sleep timeout (AC)
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE

# Hibernate timeout (AC)
powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE

# USB Selective Suspend
powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
```

### Recommended Settings for Workstation

```powershell
# Set sleep timeout to Never (workstation should stay awake)
powercfg /change standby-timeout-ac 0

# Set hibernate timeout to Never
powercfg /change hibernate-timeout-ac 0

# Disable USB Selective Suspend (may help with wake issues)
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
```

## Prevention Strategies

### 1. Disable Sleep Entirely (Recommended for Workstation)

Since wintermute is a desktop workstation that should stay awake:

```powershell
# Disable sleep on AC power
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# Disable sleep on battery (if applicable)
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-dc 0
```

### 2. Keep GPU Drivers Updated

```powershell
# Check current driver version
nvidia-smi

# Download latest from: https://www.nvidia.com/Download/index.aspx
```

### 3. Configure USB Wake Settings

Disable wake on USB devices that don't need it (keyboards/mice can stay enabled).

### 4. Monitor Docker Containers

Stop vLLM container before extended idle periods:

```powershell
.\devices\wintermute\scripts\Start-VLLM.ps1 -Action Stop
```

## Remote Diagnostics

If wintermute is accessible via Tailscale but not responding:

### From motoko

```bash
# Check if wintermute is online
ping wintermute.pangolin-vega.ts.net

# Check Tailscale status
tailscale status | grep wintermute

# Try Wake-on-LAN (if configured)
python -m tools.cli.tailnet wake wintermute
```

### Via WinRM (if system is awake)

```bash
# From motoko
ansible wintermute -i ansible/inventory/hosts.yml -m win_shell \
  -a "powershell -ExecutionPolicy Bypass -File C:\Users\mdt\dev\miket-infra-devices\devices\wintermute\scripts\Diagnose-SleepWake.ps1"
```

## Recovery Steps

If system is unresponsive:

1. **Hard Power Cycle:**
   - Hold power button for 10 seconds
   - Wait 30 seconds
   - Press power button to restart

2. **After Recovery:**
   - Run diagnostic script immediately
   - Check Event Viewer for errors
   - Review this runbook for fixes

3. **Prevent Recurrence:**
   - Apply fixes from diagnostic output
   - Consider disabling sleep entirely (workstation use case)
   - Update drivers if needed

## Related Documentation

- [Wintermute Setup Runbook](./wintermute-setup.md)
- [Wintermute Connectivity Troubleshooting](./wintermute-connectivity-troubleshooting.md)
- [Device Health Check Runbook](./device-health-check.md)
- [Windows Workstation Mode Scripts](../../devices/wintermute/scripts/Set-WorkstationMode.ps1)

