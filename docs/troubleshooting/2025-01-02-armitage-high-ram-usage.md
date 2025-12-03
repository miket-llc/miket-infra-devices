# Armitage High RAM Usage - Diagnosis and Fix

**Date:** 2025-01-02  
**Device:** armitage (Windows 11 Pro)  
**Issue:** RAM usage at 94.6% (14.68 GB / 15.52 GB used)  
**Status:** ✅ RESOLVED

## Root Cause Analysis

### Hardware Reality vs Configuration
- **Actual RAM:** 16GB (2x 8GB DDR5-5600 modules)
- **Config Files:** Incorrectly listed as 32GB
- **Windows Visible:** 15.52 GB (normal - some reserved for hardware)

### Memory Consumers
1. **WSL2 podman-machine-default:** Allocated 7.5GB (47% of total RAM)
2. **Windows System + Processes:** ~3-4GB
3. **Memory Compression:** 1.5GB (indicates critical memory pressure)
4. **Cursor processes:** ~0.9GB total
5. **Windows Defender:** ~0.3GB
6. **Dell monitoring tools:** ~0.4GB

## Fixes Applied

### 1. Created `.wslconfig` Memory Limit
**File:** `C:\Users\mdt\.wslconfig`

```ini
[wsl2]
memory=4GB
processors=4
swap=2GB
localhostForwarding=true
```

**Impact:** Limits WSL2 to 4GB instead of default 50% of RAM (7.5GB). Saves **3.5GB**.

### 2. Updated Configuration Files
- `ansible/host_vars/armitage.yml`: `memory_gb: 32` → `memory_gb: 16`
- `devices/armitage/config.yml`: `memory: 32GB DDR5` → `memory: 16GB DDR5`
- `devices/inventory.yaml`: `memory_gb: 32` → `memory_gb: 16`

### 3. Shut Down WSL2
Immediately freed memory by shutting down WSL2. Memory usage dropped from 94.6% to 86.6%.

## Results

**Before:**
- RAM Usage: 94.6% (14.68 GB used / 15.52 GB total)
- Free RAM: 0.84 GB
- Memory Compression: 1.5 GB
- WSL2 Allocation: 7.5 GB

**After WSL2 Shutdown:**
- RAM Usage: 86.6% (13.44 GB used / 15.52 GB total)
- Free RAM: 2.08 GB
- Memory Compression: 1.43 GB (slight improvement)

**Expected After WSL2 Restart (with .wslconfig):**
- WSL2 will use max 4GB instead of 7.5GB
- Additional ~3.5GB freed for Windows
- Memory compression should decrease significantly
- Overall RAM usage should drop to ~70-75%

## Next Steps

1. **Restart WSL2** when needed - it will automatically use the 4GB limit
2. **Monitor memory** using the deployed `Check-RAMUsage.ps1` script
3. **Consider closing** multiple Cursor windows if not needed (currently using ~0.9GB)
4. **Verify** memory usage after WSL2 restart to confirm improvement

## Diagnostic Script

A comprehensive RAM diagnostic script has been deployed:
- **Location:** `C:\Users\mdt\dev\armitage\scripts\Check-RAMUsage.ps1`
- **Usage:** Run directly on armitage or via Ansible:
  ```bash
  ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
    -a "powershell -ExecutionPolicy Bypass -File C:\Users\mdt\dev\armitage\scripts\Check-RAMUsage.ps1"
  ```

## Notes

- Podman machine memory cannot be changed directly for WSL machines - it respects `.wslconfig`
- The `.wslconfig` file applies to all WSL2 distributions
- Memory compression is a Windows feature that compresses memory pages when RAM is low
- High memory compression (1.5GB) indicates the system was under severe memory pressure

## Related Files

- `devices/armitage/scripts/Check-RAMUsage.ps1` - RAM diagnostic script
- `ansible/host_vars/armitage.yml` - Updated hardware specs
- `devices/armitage/config.yml` - Updated device config
- `devices/inventory.yaml` - Updated inventory


