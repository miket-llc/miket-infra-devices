<#
.SYNOPSIS
    Diagnoses what's causing fan cycling on Wintermute
.DESCRIPTION
    Checks CPU, GPU, processes, Docker containers, and scheduled tasks to identify
    what's causing fans to cycle up and down
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wintermute Fan Cycling Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check CPU Usage
Write-Host "[1] Checking CPU Usage..." -ForegroundColor Yellow
try {
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
    if ($cpu) {
        $cpuValue = [math]::Round($cpu.CounterSamples[0].CookedValue, 2)
        $color = if ($cpuValue -gt 50) { "Red" } elseif ($cpuValue -gt 20) { "Yellow" } else { "Green" }
        Write-Host "  CPU Usage: $cpuValue%" -ForegroundColor $color
        
        # Get top CPU processes
        $topProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
        Write-Host "  Top CPU processes:" -ForegroundColor Cyan
        $topProcesses | ForEach-Object {
            $cpuPercent = [math]::Round(($_.CPU / (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors), 2)
            Write-Host "    $($_.ProcessName): $cpuPercent% CPU" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  ⚠️  Error checking CPU: $_" -ForegroundColor Yellow
}
Write-Host ""

# 2. Check GPU Usage
Write-Host "[2] Checking GPU Usage..." -ForegroundColor Yellow
$nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    try {
        $gpuInfo = & $nvidiaSmi --query-gpu=name,utilization.gpu,utilization.memory,temperature.gpu,power.draw --format=csv,noheader,nounits 2>&1
        if ($LASTEXITCODE -eq 0) {
            if ($gpuInfo -match '(.+),\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)') {
                $gpuUtil = [int]$matches[2]
                $memUtil = [int]$matches[3]
                $temp = [int]$matches[4]
                $power = [double]$matches[5]
                
                Write-Host "  GPU: $($matches[1].Trim())" -ForegroundColor Cyan
                Write-Host "  GPU Utilization: $gpuUtil%" -ForegroundColor $(if ($gpuUtil -gt 5) { "Yellow" } else { "Green" })
                Write-Host "  Memory Utilization: $memUtil%" -ForegroundColor $(if ($memUtil -gt 5) { "Yellow" } else { "Green" })
                Write-Host "  Temperature: ${temp}°C" -ForegroundColor $(if ($temp -gt 60) { "Red" } elseif ($temp -gt 50) { "Yellow" } else { "Green" })
                Write-Host "  Power Draw: ${power}W" -ForegroundColor $(if ($power -gt 50) { "Yellow" } else { "Green" })
                
                if ($gpuUtil -gt 5 -or $memUtil -gt 5) {
                    Write-Host "  ⚠️  GPU is active - checking processes..." -ForegroundColor Yellow
                    $gpuProcesses = & $nvidiaSmi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1
                    if ($LASTEXITCODE -eq 0 -and $gpuProcesses) {
                        Write-Host "  Processes using GPU:" -ForegroundColor Cyan
                        $gpuProcesses | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                    }
                } else {
                    Write-Host "  ✓ GPU is idle" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Error checking GPU: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  nvidia-smi not found at expected location" -ForegroundColor Yellow
}
Write-Host ""

# 3. Check Docker Containers
Write-Host "[3] Checking Docker Containers..." -ForegroundColor Yellow
try {
    $ErrorActionPreference = "SilentlyContinue"
    $formatString = '{{.Names}}|{{.Status}}'
    $containerOutput = docker ps -a --format $formatString
    $ErrorActionPreference = "Continue"
    if ($LASTEXITCODE -eq 0 -and $containerOutput) {
        $containers = $containerOutput | Where-Object { $_ -ne "" -and $_ -notmatch "^$" }
        if ($containers) {
            Write-Host "  Docker containers:" -ForegroundColor Cyan
            $containers | ForEach-Object {
                if ($_ -match '\|') {
                    $parts = $_ -split '\|'
                    $name = $parts[0].Trim()
                    $status = $parts[1].Trim()
                    $color = if ($status -like "*Up*") { "Yellow" } else { "Gray" }
                    Write-Host "    $name : $status" -ForegroundColor $color
                    
                    if ($name -like "*vllm*" -and $status -like "*Up*") {
                        Write-Host "      ⚠️  vLLM container is RUNNING - this uses GPU and causes fan activity!" -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "  ✓ No Docker containers found" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  Docker not accessible or not running" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error checking Docker: $_" -ForegroundColor Yellow
}
Write-Host ""

# 4. Check WSL2 Distros
Write-Host "[4] Checking WSL2 Distros..." -ForegroundColor Yellow
try {
    $wslOutput = wsl --list --verbose 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslLines = $wslOutput | Where-Object { $_ -match "Running" }
        if ($wslLines) {
            Write-Host "  ⚠️  WSL2 distros are running:" -ForegroundColor Yellow
            $wslLines | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            Write-Host "  WSL2 can consume CPU/GPU resources" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ No WSL2 distros running" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  ⚠️  Error checking WSL2: $_" -ForegroundColor Yellow
}
Write-Host ""

# 5. Check Scheduled Tasks
Write-Host "[5] Checking Scheduled Tasks..." -ForegroundColor Yellow
try {
    $tasks = Get-ScheduledTask | Where-Object { $_.State -eq "Running" } | Select-Object -First 10
    if ($tasks) {
        Write-Host "  Running scheduled tasks:" -ForegroundColor Cyan
        $tasks | ForEach-Object {
            Write-Host "    $($_.TaskName)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✓ No running scheduled tasks" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Error checking scheduled tasks: $_" -ForegroundColor Yellow
}
Write-Host ""

# 6. Check Windows Services
Write-Host "[6] Checking High-CPU Services..." -ForegroundColor Yellow
try {
    $services = Get-Service | Where-Object { $_.Status -eq "Running" } | Get-Process -ErrorAction SilentlyContinue | 
        Where-Object { $_.CPU -gt 0 } | Sort-Object CPU -Descending | Select-Object -First 5
    if ($services) {
        Write-Host "  Services with CPU usage:" -ForegroundColor Cyan
        $services | ForEach-Object {
            $cpuPercent = [math]::Round(($_.CPU / (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors), 2)
            Write-Host "    $($_.ProcessName): $cpuPercent% CPU" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  ⚠️  Error checking services: $_" -ForegroundColor Yellow
}
Write-Host ""

# 7. Check for Windows Update/Indexing
Write-Host "[7] Checking Windows Background Tasks..." -ForegroundColor Yellow
try {
    $wsearch = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
    if ($wsearch -and $wsearch.Status -eq "Running") {
        Write-Host "  ⚠️  Windows Search (indexing) is running" -ForegroundColor Yellow
        Write-Host "     This can cause periodic CPU spikes" -ForegroundColor Gray
    }
    
    $wuauserv = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    if ($wuauserv -and $wuauserv.Status -eq "Running") {
        Write-Host "  ⚠️  Windows Update service is running" -ForegroundColor Yellow
        Write-Host "     May be downloading/installing updates" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ⚠️  Error checking background tasks: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if vLLM is running
$vllmRunning = $false
try {
    $ErrorActionPreference = "SilentlyContinue"
    $formatString2 = '{{.Names}}'
    $containerCheck = docker ps --filter "name=vllm-wintermute" --format $formatString2
    $ErrorActionPreference = "Continue"
    if ($LASTEXITCODE -eq 0 -and $containerCheck -like "*vllm*") {
        $vllmRunning = $true
    }
} catch {}

if ($vllmRunning) {
    Write-Host "1. STOP vLLM container if not needed:" -ForegroundColor Yellow
    Write-Host "   docker stop vllm-wintermute" -ForegroundColor White
    Write-Host "   Or: .\Start-VLLM.ps1 -Action Stop" -ForegroundColor White
    Write-Host ""
}

Write-Host "2. Check Task Manager for processes with high CPU/GPU usage" -ForegroundColor Yellow
Write-Host "   Press Ctrl+Shift+Esc to open Task Manager" -ForegroundColor White
Write-Host "   Sort by CPU or GPU to see what's using resources" -ForegroundColor White
Write-Host ""

Write-Host "3. Common causes of fan cycling:" -ForegroundColor Yellow
Write-Host "   - vLLM container running (uses GPU constantly)" -ForegroundColor White
Write-Host "   - Windows Update downloading/installing" -ForegroundColor White
Write-Host "   - Windows Search indexing files" -ForegroundColor White
Write-Host "   - WSL2 distros running in background" -ForegroundColor White
Write-Host "   - Scheduled tasks running periodically" -ForegroundColor White
Write-Host "   - Docker Desktop background processes" -ForegroundColor White
Write-Host ""

Write-Host "4. To monitor in real-time:" -ForegroundColor Yellow
Write-Host "   nvidia-smi -l 1  (GPU monitoring)" -ForegroundColor White
Write-Host "   Get-Process | Sort-Object CPU -Descending | Select-Object -First 10" -ForegroundColor White
Write-Host ""

