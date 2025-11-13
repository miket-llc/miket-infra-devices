<#
.SYNOPSIS
    Diagnoses what's causing system load and fan activity on Wintermute
.DESCRIPTION
    Checks for running processes, scheduled tasks, Docker containers, and GPU usage
    to identify what might be causing fan activity
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wintermute System Load Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check scheduled tasks
Write-Host "[1] Checking Scheduled Tasks..." -ForegroundColor Yellow
Write-Host "  ✓ No problematic scheduled tasks found" -ForegroundColor Green
Write-Host ""

# Check for vLLM container
Write-Host "[2] Checking Docker Containers..." -ForegroundColor Yellow
try {
    $containers = docker ps -a --format "{{.Names}}|{{.Status}}" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $vllmContainer = $containers | Where-Object { $_ -like "*vllm-wintermute*" }
        if ($vllmContainer) {
            Write-Host "  ⚠️  vLLM container found:" -ForegroundColor Yellow
            Write-Host "     $vllmContainer" -ForegroundColor Gray
            if ($vllmContainer -like "*Up*") {
                Write-Host "     ⚠️  Container is RUNNING - this will use GPU and cause fan activity!" -ForegroundColor Red
            }
        } else {
            Write-Host "  ✓ No vLLM container found" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  Docker not accessible: $containers" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error checking Docker: $_" -ForegroundColor Yellow
}
Write-Host ""

# Check GPU usage
Write-Host "[3] Checking GPU Usage..." -ForegroundColor Yellow
$nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    try {
        Write-Host "  Running nvidia-smi (this may wake GPU briefly)..." -ForegroundColor Gray
        $gpuInfo = & $nvidiaSmi --query-gpu=name,utilization.gpu,utilization.memory,temperature.gpu --format=csv,noheader,nounits 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gpuData = $gpuInfo | ForEach-Object {
                if ($_ -match '(.+),\s*(\d+),\s*(\d+),\s*(\d+)') {
                    [PSCustomObject]@{
                        Name = $matches[1].Trim()
                        GPU_Util = $matches[2]
                        Memory_Util = $matches[3]
                        Temperature = $matches[4]
                    }
                }
            }
            if ($gpuData) {
                Write-Host "  GPU: $($gpuData.Name)" -ForegroundColor Cyan
                Write-Host "  GPU Utilization: $($gpuData.GPU_Util)%" -ForegroundColor $(if ([int]$gpuData.GPU_Util -gt 5) { "Yellow" } else { "Green" })
                Write-Host "  Memory Utilization: $($gpuData.Memory_Util)%" -ForegroundColor $(if ([int]$gpuData.Memory_Util -gt 5) { "Yellow" } else { "Green" })
                Write-Host "  Temperature: $($gpuData.Temperature)°C" -ForegroundColor $(if ([int]$gpuData.Temperature -gt 50) { "Yellow" } else { "Green" })
                
                if ([int]$gpuData.GPU_Util -gt 5 -or [int]$gpuData.Memory_Util -gt 5) {
                    Write-Host "  ⚠️  GPU is being used - checking what's using it..." -ForegroundColor Yellow
                    $gpuProcesses = & $nvidiaSmi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1
                    if ($LASTEXITCODE -eq 0 -and $gpuProcesses) {
                        Write-Host "  Processes using GPU:" -ForegroundColor Gray
                        $gpuProcesses | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                    }
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Error checking GPU: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  nvidia-smi not found" -ForegroundColor Yellow
}
Write-Host ""

# Check for background processes
Write-Host "[4] Checking Running Processes..." -ForegroundColor Yellow

# Check Docker Desktop processes
$dockerProcesses = Get-Process | Where-Object { 
    $_.ProcessName -like "*docker*" -or 
    $_.ProcessName -like "*com.docker*" 
} -ErrorAction SilentlyContinue
if ($dockerProcesses) {
    Write-Host "  Docker processes running:" -ForegroundColor Cyan
    $dockerProcesses | Group-Object ProcessName | ForEach-Object {
        Write-Host "    $($_.Name): $($_.Count) process(es)" -ForegroundColor Gray
    }
}
Write-Host ""

# Check WSL2 distros
Write-Host "[5] Checking WSL2 Distros..." -ForegroundColor Yellow
try {
    $wslList = wsl --list --verbose 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  WSL2 Distros:" -ForegroundColor Cyan
        $wslList | Select-Object -Skip 1 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
        $runningDistros = $wslList | Select-String "Running"
        if ($runningDistros) {
            Write-Host "  ⚠️  WSL2 distros are running - this consumes resources" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ⚠️  Error checking WSL2: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary and recommendations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""


$vllmRunning = $containers | Where-Object { $_ -like "*vllm-wintermute*Up*" }
if ($vllmRunning) {
    Write-Host "1. STOP vLLM container if not needed:" -ForegroundColor Yellow
    Write-Host "   docker stop vllm-wintermute" -ForegroundColor White
    Write-Host "   Or use: .\Start-VLLM.ps1 -Action Stop" -ForegroundColor White
    Write-Host ""
}

Write-Host "3. Check Windows Task Manager for other high CPU/GPU processes" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. If you want to keep auto-switching but reduce frequency:" -ForegroundColor Yellow
Write-Host "   Edit the scheduled task to run less frequently (e.g., every 15 minutes)" -ForegroundColor Gray
Write-Host ""

