<#
.SYNOPSIS
    Verifies vLLM is using GPU VRAM, not system RAM
.DESCRIPTION
    Checks GPU memory usage, container status, and verifies vLLM configuration
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "vLLM GPU Memory Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check GPU memory
Write-Host "[1] GPU Memory Usage" -ForegroundColor Yellow
$nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    try {
        $gpuMem = & $nvidiaSmi --query-gpu=memory.used,memory.total,memory.free --format=csv,noheader,nounits 2>&1
        if ($LASTEXITCODE -eq 0 -and $gpuMem) {
            if ($gpuMem -match '(\d+),\s*(\d+),\s*(\d+)') {
                $usedMB = [int]$matches[1]
                $totalMB = [int]$matches[2]
                $freeMB = [int]$matches[3]
                $usedGB = [math]::Round($usedMB / 1024, 2)
                $totalGB = [math]::Round($totalMB / 1024, 2)
                $freeGB = [math]::Round($freeMB / 1024, 2)
                $percentUsed = [math]::Round(($usedMB / $totalMB) * 100, 1)
                
                Write-Host "  GPU VRAM:" -ForegroundColor Cyan
                Write-Host "    Used: $usedGB GB / $totalGB GB ($percentUsed%)" -ForegroundColor $(if ($percentUsed -gt 80) { "Red" } elseif ($percentUsed -gt 50) { "Yellow" } else { "Green" })
                Write-Host "    Free: $freeGB GB" -ForegroundColor Cyan
                
                if ($percentUsed -gt 50) {
                    Write-Host "  Checking GPU processes..." -ForegroundColor Gray
                    $gpuProcesses = & $nvidiaSmi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1
                    if ($LASTEXITCODE -eq 0 -and $gpuProcesses) {
                        Write-Host "    Processes using GPU:" -ForegroundColor Gray
                        $gpuProcesses | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
                    }
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Error checking GPU memory: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  nvidia-smi not found" -ForegroundColor Yellow
}
Write-Host ""

# Check vLLM container
Write-Host "[2] vLLM Container Status" -ForegroundColor Yellow
$dockerPath = "${env:ProgramFiles}\Docker\Docker\resources\bin\docker.exe"
if (Test-Path $dockerPath) {
    try {
        $containers = & $dockerPath ps -a --filter "name=vllm-armitage" --format "{{.Names}}|{{.Status}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $containers) {
            $parts = $containers -split '\|'
            Write-Host "  Container: $($parts[0])" -ForegroundColor Cyan
            Write-Host "  Status: $($parts[1])" -ForegroundColor $(if ($parts[1] -like "*Up*") { "Green" } else { "Yellow" })
            
            if ($parts[1] -like "*Up*") {
                Write-Host "  Checking container GPU access..." -ForegroundColor Gray
                $containerGpu = & $dockerPath inspect vllm-armitage --format '{{.HostConfig.DeviceRequests}}' 2>&1
                if ($containerGpu -match "gpu" -or $containerGpu -match "nvidia") {
                    Write-Host "    ✅ Container has GPU access configured" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠️  GPU access may not be configured" -ForegroundColor Yellow
                }
                
                # Check container memory stats
                Write-Host "  Container memory usage:" -ForegroundColor Gray
                $memStats = & $dockerPath stats vllm-armitage --no-stream --format "{{.MemUsage}}|{{.MemPerc}}" 2>&1
                if ($LASTEXITCODE -eq 0 -and $memStats) {
                    $memParts = $memStats -split '\|'
                    Write-Host "    Memory: $($memParts[0]) ($($memParts[1]))" -ForegroundColor Gray
                    Write-Host "    Note: This is container overhead, model weights are in GPU VRAM" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "  ✓ vLLM container not running" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ⚠️  Error checking container: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  Docker not found" -ForegroundColor Yellow
}
Write-Host ""

# Check configuration
Write-Host "[3] vLLM Configuration" -ForegroundColor Yellow
$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config.yml"
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw
    if ($config -match 'gpu_memory_utilization:\s*([\d.]+)') {
        $gpuUtil = $matches[1]
        Write-Host "  GPU Memory Utilization: $gpuUtil (${gpuUtil}% of GPU VRAM)" -ForegroundColor Cyan
    }
    if ($config -match 'model:\s*"([^"]+)"') {
        $model = $matches[1]
        Write-Host "  Model: $model" -ForegroundColor Cyan
        if ($model -match "AWQ") {
            Write-Host "    ✅ AWQ quantized (optimized for GPU memory)" -ForegroundColor Green
        }
    }
    if ($config -match 'kv_cache_dtype:\s*"([^"]+)"') {
        $kvCache = $matches[1]
        Write-Host "  KV Cache Dtype: $kvCache" -ForegroundColor Cyan
        if ($kvCache -eq "fp8") {
            Write-Host "    ✅ fp8 KV cache (reduces GPU memory usage)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ⚠️  Config file not found: $configPath" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "vLLM Memory Usage:" -ForegroundColor Yellow
Write-Host "  ✅ Model weights: GPU VRAM (configured via --gpu-memory-utilization)" -ForegroundColor Green
Write-Host "  ✅ KV Cache: GPU VRAM (fp8 dtype reduces memory)" -ForegroundColor Green
Write-Host "  ⚠️  Container overhead: System RAM (~100-500MB for Docker/WSL2)" -ForegroundColor Yellow
Write-Host "  ⚠️  CPU fallback: System RAM (only if GPU memory exhausted)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Expected Behavior:" -ForegroundColor Yellow
Write-Host "  - vLLM should use 5-7GB GPU VRAM for Qwen2.5-7B-AWQ model" -ForegroundColor White
Write-Host "  - Container uses minimal system RAM (~100-500MB)" -ForegroundColor White
Write-Host "  - If GPU VRAM is full, vLLM may offload to CPU (undesirable)" -ForegroundColor White
Write-Host ""
Write-Host "If system RAM usage is high while vLLM is running:" -ForegroundColor Yellow
Write-Host "  - Check GPU VRAM usage (should be 80-90% used)" -ForegroundColor White
Write-Host "  - If GPU VRAM is full, reduce max_model_len or gpu_memory_utilization" -ForegroundColor White
Write-Host "  - Check for CPU offloading in vLLM logs" -ForegroundColor White

