<#
.SYNOPSIS
    Diagnoses RAM usage on Armitage workstation and writes output to file
.DESCRIPTION
    Checks system RAM usage, top processes, containers, WSL2, and GPU memory
    Outputs to both console and file for remote retrieval
#>

$outputFile = "C:\Users\mdt\dev\armitage\scripts\ram-diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

function Write-OutputBoth {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $outputFile -Value $Message
}

Write-OutputBoth "========================================"
Write-OutputBoth "Armitage RAM Usage Diagnostics"
Write-OutputBoth "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-OutputBoth "========================================"
Write-OutputBoth ""

# Get overall system memory
Write-OutputBoth "[1] System Memory Overview"
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = $totalRAM - $freeRAM
    $percentUsed = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
    
    Write-OutputBoth "  Total RAM: $totalRAM GB"
    $percentStr = "$percentUsed%"
    Write-OutputBoth "  Used RAM: $usedRAM GB ($percentStr)"
    Write-OutputBoth "  Free RAM: $freeRAM GB"
    
    # Check memory compression
    $memInfo = Get-Counter '\Memory\System Cache Resident Bytes', '\Memory\Modified Page List Bytes', '\Memory\Standby Cache Core Bytes', '\Memory\Standby Cache Normal Priority Bytes', '\Memory\Standby Cache Reserve Bytes' -ErrorAction SilentlyContinue
    if ($memInfo) {
        $compressed = Get-Counter '\Memory\Compressed Bytes' -ErrorAction SilentlyContinue
        if ($compressed) {
            $compressedGB = [math]::Round($compressed.CounterSamples[0].CookedValue / 1GB, 2)
            Write-OutputBoth "  Compressed Memory: $compressedGB GB"
        }
    }
    
    if ($percentUsed -gt 80) {
        Write-OutputBoth "  ⚠️  WARNING: RAM usage is very high!"
    } elseif ($percentUsed -gt 60) {
        Write-OutputBoth "  ⚠️  RAM usage is elevated"
    }
} catch {
    Write-OutputBoth "  ⚠️  Error checking system memory: $_"
}
Write-OutputBoth ""

# Top processes by memory
Write-OutputBoth "[2] Top 15 Processes by Memory Usage"
try {
    $topProcs = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 15
    Write-OutputBoth ""
    foreach ($proc in $topProcs) {
        $memGB = [math]::Round($proc.WorkingSet / 1GB, 2)
        Write-OutputBoth "  $($proc.ProcessName): $memGB GB (PID: $($proc.Id))"
    }
} catch {
    Write-OutputBoth "  ⚠️  Error checking processes: $_"
}
Write-OutputBoth ""

# Check vLLM container
Write-OutputBoth "[3] vLLM Container Status"
try {
    $dockerPath = "${env:ProgramFiles}\Docker\Docker\resources\bin\docker.exe"
    if (Test-Path $dockerPath) {
        $containers = & $dockerPath ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $vllmContainer = $containers | Where-Object { $_ -like "*vllm-armitage*" }
            if ($vllmContainer) {
                Write-OutputBoth "  vLLM container found:"
                $vllmContainer | ForEach-Object {
                    $parts = $_ -split '\|'
                    Write-OutputBoth "    Name: $($parts[0])"
                    Write-OutputBoth "    Status: $($parts[1])"
                    Write-OutputBoth "    Image: $($parts[2])"
                }
                
                # Check if running and get stats
                $running = $containers | Where-Object { $_ -like "*vllm-armitage*Up*" }
                if ($running) {
                    Write-OutputBoth "  ⚠️  vLLM container is RUNNING - this uses significant RAM!"
                    try {
                        $stats = & $dockerPath stats vllm-armitage --no-stream --format "{{.MemUsage}}|{{.MemPerc}}|{{.CPUPerc}}" 2>&1
                        if ($LASTEXITCODE -eq 0 -and $stats) {
                            $statParts = $stats -split '\|'
                            Write-OutputBoth "    Memory Usage: $($statParts[0])"
                            Write-OutputBoth "    Memory %: $($statParts[1])"
                            Write-OutputBoth "    CPU %: $($statParts[2])"
                        }
                    } catch {
                        Write-OutputBoth "    Could not get container stats"
                    }
                }
            } else {
                Write-OutputBoth "  ✓ No vLLM container found"
            }
        } else {
            Write-OutputBoth "  ⚠️  Docker command failed: $containers"
        }
    } else {
        Write-OutputBoth "  ⚠️  Docker not found at expected path"
    }
} catch {
    Write-OutputBoth "  ⚠️  Error checking Docker: $_"
}
Write-OutputBoth ""

# Check WSL2 distros and memory
Write-OutputBoth "[4] WSL2 Distros and Memory"
try {
    $wslList = wsl --list --verbose 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-OutputBoth "  WSL2 Distros:"
        $wslList | Select-Object -Skip 1 | ForEach-Object {
            Write-OutputBoth "    $_"
        }
        
        $runningDistros = $wslList | Select-String "Running"
        if ($runningDistros) {
            Write-OutputBoth "  ⚠️  WSL2 distros are running - each can use 4-8GB RAM"
            
            # Check .wslconfig
            $wslConfig = "$env:USERPROFILE\.wslconfig"
            if (Test-Path $wslConfig) {
                Write-OutputBoth "  .wslconfig found:"
                Get-Content $wslConfig | ForEach-Object { Write-OutputBoth "    $_" }
            } else {
                Write-OutputBoth "  ⚠️  .wslconfig NOT found - WSL2 may use default 50% of RAM!"
            }
        } else {
            Write-OutputBoth "  ✓ No WSL2 distros running"
        }
    }
} catch {
    Write-OutputBoth "  ⚠️  Error checking WSL2: $_"
}
Write-OutputBoth ""

# Check Docker/Podman processes
Write-OutputBoth "[5] Docker/Podman Processes"
try {
    $dockerProcesses = Get-Process | Where-Object { 
        $_.ProcessName -like "*docker*" -or 
        $_.ProcessName -like "*com.docker*" -or
        $_.ProcessName -like "*podman*"
    } -ErrorAction SilentlyContinue
    
    if ($dockerProcesses) {
        Write-OutputBoth "  Container runtime processes:"
        $dockerProcesses | Group-Object ProcessName | ForEach-Object {
            $totalMem = ($_.Group | Measure-Object -Property WorkingSet -Sum).Sum
            $memGB = [math]::Round($totalMem / 1GB, 2)
            Write-OutputBoth "    $($_.Name): $($_.Count) process(es), $memGB GB total"
        }
    } else {
        Write-OutputBoth "  ✓ No Docker/Podman processes found"
    }
} catch {
    Write-OutputBoth "  ⚠️  Error checking container processes: $_"
}
Write-OutputBoth ""

# Check GPU memory
Write-OutputBoth "[6] GPU Memory Usage"
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
                
                Write-OutputBoth "  GPU Memory:"
                $gpuPercentStr = "$percentUsed%"
                Write-OutputBoth "    Used: $usedGB GB / $totalGB GB ($gpuPercentStr)"
                Write-OutputBoth "    Free: $freeGB GB"
                
                if ($percentUsed -gt 50) {
                    Write-OutputBoth "  ⚠️  GPU memory is being used - checking processes..."
                    $gpuProcesses = & $nvidiaSmi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1
                    if ($LASTEXITCODE -eq 0 -and $gpuProcesses) {
                        Write-OutputBoth "    Processes using GPU:"
                        $gpuProcesses | ForEach-Object { Write-OutputBoth "      $_" }
                    }
                }
            }
        }
    } catch {
        Write-OutputBoth "  ⚠️  Error checking GPU memory: $_"
    }
} else {
    Write-OutputBoth "  ⚠️  nvidia-smi not found"
}
Write-OutputBoth ""

# Summary and recommendations
Write-OutputBoth "========================================"
Write-OutputBoth "Summary and Recommendations"
Write-OutputBoth "========================================"
Write-OutputBoth ""

if ($percentUsed -gt 80) {
    $criticalPercentStr = "$percentUsed%"
    Write-OutputBoth "WARNING: System RAM usage is CRITICAL ($criticalPercentStr)"
    Write-OutputBoth "   Consider:"
    Write-OutputBoth "   - Stopping vLLM container if not needed"
    Write-OutputBoth "   - Shutting down WSL2 if not needed"
    Write-OutputBoth "   - Closing unnecessary applications"
    Write-OutputBoth "   - Restarting Windows to clear memory leaks"
    Write-OutputBoth ""
}

Write-OutputBoth "Output file: $outputFile"
Write-OutputBoth ""

