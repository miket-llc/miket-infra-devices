<#
.SYNOPSIS
    Diagnoses RAM usage on Armitage workstation
.DESCRIPTION
    Checks system RAM usage, top processes, containers, WSL2, and GPU memory
    to identify what's consuming memory
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Armitage RAM Usage Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get overall system memory
Write-Host "[1] System Memory Overview" -ForegroundColor Yellow
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = $totalRAM - $freeRAM
    $percentUsed = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
    
    Write-Host "  Total RAM: $totalRAM GB" -ForegroundColor Cyan
    Write-Host "  Used RAM: $usedRAM GB ($percentUsed%)" -ForegroundColor $(if ($percentUsed -gt 80) { "Red" } elseif ($percentUsed -gt 60) { "Yellow" } else { "Green" })
    Write-Host "  Free RAM: $freeRAM GB" -ForegroundColor Cyan
    
    if ($percentUsed -gt 80) {
        Write-Host "  ⚠️  WARNING: RAM usage is very high!" -ForegroundColor Red
    } elseif ($percentUsed -gt 60) {
        Write-Host "  ⚠️  RAM usage is elevated" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error checking system memory: $_" -ForegroundColor Yellow
}
Write-Host ""

# Top processes by memory
Write-Host "[2] Top 10 Processes by Memory Usage" -ForegroundColor Yellow
try {
    Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | 
        Format-Table @{Name="Process";Expression={$_.ProcessName}}, 
                     @{Name="Memory (GB)";Expression={[math]::Round($_.WorkingSet/1GB, 2)}}, 
                     @{Name="CPU (s)";Expression={[math]::Round($_.CPU, 2)}} -AutoSize
} catch {
    Write-Host "  ⚠️  Error checking processes: $_" -ForegroundColor Yellow
}
Write-Host ""

# Check vLLM container
Write-Host "[3] vLLM Container Status" -ForegroundColor Yellow
try {
    $containers = docker ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $vllmContainer = $containers | Where-Object { $_ -like "*vllm-armitage*" }
        if ($vllmContainer) {
            Write-Host "  vLLM container found:" -ForegroundColor Cyan
            $vllmContainer | ForEach-Object {
                $parts = $_ -split '\|'
                Write-Host "    Name: $($parts[0])" -ForegroundColor Gray
                Write-Host "    Status: $($parts[1])" -ForegroundColor $(if ($parts[1] -like "*Up*") { "Yellow" } else { "Green" })
                Write-Host "    Image: $($parts[2])" -ForegroundColor Gray
            }
            
            # Check if running and get stats
            $running = $containers | Where-Object { $_ -like "*vllm-armitage*Up*" }
            if ($running) {
                Write-Host "  ⚠️  vLLM container is RUNNING - this uses significant RAM!" -ForegroundColor Yellow
                Write-Host "  Checking container stats..." -ForegroundColor Gray
                try {
                    $stats = docker stats vllm-armitage --no-stream --format "{{.MemUsage}}|{{.MemPerc}}|{{.CPUPerc}}" 2>&1
                    if ($LASTEXITCODE -eq 0 -and $stats) {
                        $statParts = $stats -split '\|'
                        Write-Host "    Memory Usage: $($statParts[0])" -ForegroundColor Cyan
                        Write-Host "    Memory %: $($statParts[1])" -ForegroundColor Cyan
                        Write-Host "    CPU %: $($statParts[2])" -ForegroundColor Cyan
                    }
                } catch {
                    Write-Host "    Could not get container stats" -ForegroundColor Gray
                }
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

# Check WSL2 distros and memory
Write-Host "[4] WSL2 Distros and Memory" -ForegroundColor Yellow
try {
    $wslList = wsl --list --verbose 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  WSL2 Distros:" -ForegroundColor Cyan
        $wslList | Select-Object -Skip 1 | ForEach-Object {
            $color = if ($_ -match "Running") { "Yellow" } else { "Green" }
            Write-Host "    $_" -ForegroundColor $color
        }
        
        $runningDistros = $wslList | Select-String "Running"
        if ($runningDistros) {
            Write-Host "  ⚠️  WSL2 distros are running - each can use 4-8GB RAM" -ForegroundColor Yellow
            
            # Try to get WSL2 memory usage (requires wsl command inside distro)
            Write-Host "  Checking WSL2 memory usage..." -ForegroundColor Gray
            try {
                # Check podman-machine-default if it exists
                if ($wslList -match "podman-machine-default.*Running") {
                    Write-Host "    podman-machine-default is running (typically uses 8GB)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "    Could not get detailed WSL2 memory info" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✓ No WSL2 distros running" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  ⚠️  Error checking WSL2: $_" -ForegroundColor Yellow
}
Write-Host ""

# Check Docker/Podman processes
Write-Host "[5] Docker/Podman Processes" -ForegroundColor Yellow
try {
    $dockerProcesses = Get-Process | Where-Object { 
        $_.ProcessName -like "*docker*" -or 
        $_.ProcessName -like "*com.docker*" -or
        $_.ProcessName -like "*podman*"
    } -ErrorAction SilentlyContinue
    
    if ($dockerProcesses) {
        Write-Host "  Container runtime processes:" -ForegroundColor Cyan
        $dockerProcesses | Group-Object ProcessName | ForEach-Object {
            $totalMem = ($_.Group | Measure-Object -Property WorkingSet -Sum).Sum
            $memGB = [math]::Round($totalMem / 1GB, 2)
            Write-Host "    $($_.Name): $($_.Count) process(es), $memGB GB total" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✓ No Docker/Podman processes found" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Error checking container processes: $_" -ForegroundColor Yellow
}
Write-Host ""

# Check GPU memory
Write-Host "[6] GPU Memory Usage" -ForegroundColor Yellow
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
                
                Write-Host "  GPU Memory:" -ForegroundColor Cyan
                Write-Host "    Used: $usedGB GB / $totalGB GB ($percentUsed%)" -ForegroundColor $(if ($percentUsed -gt 80) { "Red" } elseif ($percentUsed -gt 50) { "Yellow" } else { "Green" })
                Write-Host "    Free: $freeGB GB" -ForegroundColor Cyan
                
                if ($percentUsed -gt 50) {
                    Write-Host "  ⚠️  GPU memory is being used - checking processes..." -ForegroundColor Yellow
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

# Summary and recommendations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary & Recommendations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$vllmRunning = $containers | Where-Object { $_ -like "*vllm-armitage*Up*" }
if ($vllmRunning) {
    Write-Host "1. vLLM container is RUNNING" -ForegroundColor Yellow
    Write-Host "   This typically uses 4-8GB RAM + GPU memory" -ForegroundColor Gray
    Write-Host "   To stop: docker stop vllm-armitage" -ForegroundColor White
    Write-Host "   Or: .\Start-VLLM.ps1 -Action Stop" -ForegroundColor White
    Write-Host ""
}

$wslRunning = $wslList | Select-String "Running"
if ($wslRunning) {
    Write-Host "2. WSL2 distros are running" -ForegroundColor Yellow
    Write-Host "   Each WSL2 distro can use 4-8GB RAM" -ForegroundColor Gray
    Write-Host "   To stop all: wsl --shutdown" -ForegroundColor White
    Write-Host "   To stop podman-machine: wsl -t podman-machine-default" -ForegroundColor White
    Write-Host ""
}

if ($percentUsed -gt 80) {
    Write-Host "3. System RAM usage is CRITICAL ($percentUsed%)" -ForegroundColor Red
    Write-Host "   Consider:" -ForegroundColor Yellow
    Write-Host "   - Stopping vLLM container if not needed" -ForegroundColor White
    Write-Host "   - Shutting down WSL2 if not needed" -ForegroundColor White
    Write-Host "   - Closing unnecessary applications" -ForegroundColor White
    Write-Host "   - Restarting Windows to clear memory leaks" -ForegroundColor White
    Write-Host ""
}

Write-Host "For detailed process info, check Task Manager:" -ForegroundColor Cyan
Write-Host "  Press Ctrl+Shift+Esc" -ForegroundColor White


