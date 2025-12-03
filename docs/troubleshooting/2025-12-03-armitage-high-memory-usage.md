# Armitage High Memory Usage - Troubleshooting Report

**Date:** 2025-12-03  
**Device:** armitage (Windows 11 Pro)  
**Issue:** RAM usage at 90.5% (14.05 GB / 15.52 GB used)  
**Status:** 🔴 CRITICAL - Action Required

## Executive Summary

Armitage is experiencing **critical memory pressure** with 90.5% RAM utilization despite WSL2 being stopped. The presence of **1.21 GB of memory compression** indicates severe memory pressure that requires immediate attention.

## Current State

### Memory Metrics
- **Total RAM:** 15.52 GB (16 GB physical, ~0.5 GB reserved for hardware)
- **Used RAM:** 14.05 GB (90.5%)
- **Free RAM:** 1.47 GB
- **Memory Compression:** 1.21 GB ⚠️ **CRITICAL INDICATOR**

### Configuration Status
- ✅ **.wslconfig exists** with 4GB limit (correctly configured)
- ✅ **WSL2 distros are stopped** (not contributing to memory usage)
- ✅ **vLLM container not running** (not contributing to memory usage)
- ⚠️ **Memory compression active** (indicates system under severe pressure)

## Root Cause Analysis

### vLLM Memory Usage Clarification

**Important:** vLLM is correctly configured to use **GPU VRAM**, not system RAM:
- ✅ `--gpus all` flag enables GPU access
- ✅ `gpu_memory_utilization: 0.90` (90% of GPU VRAM)
- ✅ AWQ quantized model (~5GB GPU VRAM)
- ✅ fp8 KV cache dtype (reduces GPU memory)
- ⚠️ Container overhead: ~100-500MB system RAM (Docker/WSL2 only)

**vLLM should NOT be consuming significant system RAM.** If system RAM usage is high while vLLM is running, check:
1. GPU VRAM usage (should be 80-90% used)
2. Container logs for CPU offloading warnings
3. If GPU VRAM is full, vLLM may offload to CPU (undesirable)

### Primary Memory Consumers

1. **Memory Compression: 1.21 GB** 🔴
   - Windows is compressing memory pages due to low available RAM
   - This is a **symptom**, not a cause - indicates severe memory pressure
   - High compression = system struggling to manage memory
   - **NOT caused by vLLM** (vLLM uses GPU VRAM)

2. **Multiple Cursor Instances: 0.72 GB total**
   - Cursor (PID 54720): 0.32 GB
   - Cursor (PID 46892): 0.28 GB
   - Cursor (PID 57368): 0.12 GB
   - **Recommendation:** Close unused Cursor windows

3. **System Services:**
   - svchost (PID 5164): 0.34 GB
   - OCControl.Service (Alienware): 0.33 GB
   - explorer: 0.31 GB
   - Windows Defender (MsMpEng): 0.22 GB
   - Dell monitoring tools: 0.20 GB

4. **Other Applications:**
   - steamwebhelper: 0.25 GB
   - OneDrive: 0.18 GB
   - netdata: 0.13 GB

## Immediate Actions Required

### 1. Close Unused Applications
```powershell
# Close unused Cursor windows
# Check Task Manager (Ctrl+Shift+Esc) and close unnecessary instances
```

### 2. Check for Memory Leaks
The high memory usage with WSL2 stopped suggests possible memory leaks:
- **Windows Defender** may be scanning excessively
- **Alienware/Dell services** may have memory leaks
- **System services** may be holding memory

### 3. Restart Windows (Recommended)
A restart will:
- Clear memory leaks
- Reset memory compression
- Free up cached memory
- Restore system to clean state

**Command:**
```powershell
# Schedule restart (optional - can do manually)
shutdown /r /t 0
```

### 4. Optimize Windows Defender
Add exclusions to reduce scanning overhead:

```powershell
# Run as Administrator
Add-MpPreference -ExclusionPath "C:\Users\mdt\dev"
Add-MpPreference -ExclusionPath "C:\ProgramData\Docker"
Add-MpPreference -ExclusionProcess "powershell.exe"
Add-MpPreference -ExclusionProcess "wsl.exe"
```

### 5. Review Alienware/Dell Services
Consider disabling non-essential Alienware/Dell services if not needed:
- OCControl.Service (0.33 GB)
- Dell.TechHub.Instrumentation.SubAgent (0.20 GB)

## Expected Results After Fixes

**After restart and optimizations:**
- Memory usage should drop to **60-70%** (normal for Windows 11)
- Memory compression should be **< 0.5 GB** or eliminated
- Free RAM should be **4-6 GB**
- System should be more responsive

## Monitoring

### Check Memory Usage
```bash
# From motoko (Ansible control node)
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "powershell.exe -ExecutionPolicy Bypass -File 'C:/Users/mdt/dev/armitage/scripts/Get-MemoryInfo.ps1'"

# Then read the output
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "type 'C:/Users/mdt/dev/armitage/scripts/memory-info.txt'"
```

### Netdata Monitoring
Armitage streams metrics to motoko Netdata parent. Check:
- Memory usage trends
- Memory compression over time
- Process memory consumption

## Long-Term Recommendations

### 1. Consider RAM Upgrade
With 16 GB RAM and high-end GPU workloads:
- **Current:** 16 GB (marginal for gaming + development + AI workloads)
- **Recommended:** 32 GB (would eliminate memory pressure)
- **Cost:** ~$100-150 for 2x 16GB DDR5 modules

### 2. Optimize Startup Programs
Review and disable unnecessary startup programs:
- Alienware/Dell bloatware
- Unused gaming overlays
- Background services not needed

### 3. Regular Maintenance
- **Weekly:** Check memory usage via diagnostic script
- **Monthly:** Review and close unused applications
- **Quarterly:** Consider Windows restart if memory usage > 80%

## Diagnostic Scripts

### Quick Memory Check
```bash
# Deployed script
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "powershell.exe -ExecutionPolicy Bypass -File 'C:/Users/mdt/dev/armitage/scripts/Get-MemoryInfo.ps1'"
```

### Verify vLLM GPU Usage
```bash
# Check that vLLM is using GPU VRAM, not system RAM
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "powershell.exe -ExecutionPolicy Bypass -File 'C:/Users/mdt/dev/armitage/scripts/Check-VLLM-GPU.ps1'"
```

### Full Diagnostic (Original)
```bash
ansible armitage -i ansible/inventory/hosts.yml -m win_shell \
  -a "powershell.exe -ExecutionPolicy Bypass -File 'C:/Users/mdt/dev/armitage/scripts/Check-RAMUsage.ps1'"
```

## Related Documentation

- `docs/troubleshooting/2025-01-02-armitage-high-ram-usage.md` - Previous memory issue (WSL2 related)
- `devices/armitage/scripts/Get-MemoryInfo.ps1` - Simple memory diagnostic
- `devices/armitage/scripts/Check-RAMUsage.ps1` - Comprehensive diagnostic

## Next Steps

1. ✅ **Immediate:** Restart Windows to clear memory leaks
2. ✅ **Short-term:** Close unused Cursor windows
3. ✅ **Short-term:** Optimize Windows Defender exclusions
4. ⏳ **Medium-term:** Review and disable unnecessary services
5. ⏳ **Long-term:** Consider RAM upgrade to 32 GB

---

**Generated:** 2025-12-03  
**Diagnostic Script:** `Get-MemoryInfo.ps1`  
**Status:** Awaiting user action (restart recommended)

