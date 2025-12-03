<#
.SYNOPSIS
    Comprehensive debugging script for Docker Desktop + NVIDIA GPU setup on Windows/WSL2
.DESCRIPTION
    Checks Docker Desktop, WSL2, NVIDIA GPU, and NVIDIA Container Toolkit status
    Helps diagnose issues with vLLM container GPU access
#>

$ErrorActionPreference = "Continue"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

$header = @"
╔═══════════════════════════════════════════════════════════════╗
║   Docker Desktop + NVIDIA GPU Debugging Script               ║
║   Armitage - Windows 11 + RTX 4070                           ║
╚═══════════════════════════════════════════════════════════════╝
"@
Write-Host $header -ForegroundColor Cyan

$issues = @()
$warnings = @()

# ============================================================================
# 1. Check Windows NVIDIA GPU
# ============================================================================
Write-Host "`n[1/8] Checking Windows NVIDIA GPU..." -ForegroundColor Yellow
$nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    Write-Host "  ✅ nvidia-smi.exe found" -ForegroundColor Green
    try {
        $gpuInfo = & $nvidiaSmi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  GPU Info: $gpuInfo" -ForegroundColor Green
        } else {
            $issues += "nvidia-smi failed: $gpuInfo"
            Write-Host "  ❌ nvidia-smi failed: $gpuInfo" -ForegroundColor Red
        }
    } catch {
        $issues += "nvidia-smi error: $_"
        Write-Host "  ❌ Error running nvidia-smi: $_" -ForegroundColor Red
    }
} else {
    $issues += "NVIDIA drivers not found"
    Write-Host "  ❌ NVIDIA drivers not found at expected location" -ForegroundColor Red
}

# ============================================================================
# 2. Check WSL2 Installation
# ============================================================================
Write-Host "`n[2/8] Checking WSL2 installation..." -ForegroundColor Yellow
try {
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ WSL2 is installed" -ForegroundColor Green
        Write-Host "  $wslStatus" -ForegroundColor Cyan
    } else {
        $issues += "WSL2 not properly installed"
        Write-Host "  ❌ WSL2 status check failed" -ForegroundColor Red
    }
} catch {
    $issues += "WSL2 check failed: $_"
    Write-Host "  ❌ Error checking WSL2: $_" -ForegroundColor Red
}

# Check WSL2 distributions
Write-Host "`n  Checking WSL2 distributions..." -ForegroundColor Cyan
try {
    $wslList = wsl --list --verbose 2>&1
    Write-Host $wslList
    if ($wslList -match "docker-desktop") {
        Write-Host "  ✅ docker-desktop distro found" -ForegroundColor Green
        if ($wslList -match "docker-desktop.*Running") {
            Write-Host "  ✅ docker-desktop distro is running" -ForegroundColor Green
        } else {
            $warnings += "docker-desktop distro exists but is not running"
            Write-Host "  ⚠️  docker-desktop distro is not running" -ForegroundColor Yellow
        }
    } else {
        $warnings += "docker-desktop distro not found (may be initializing)"
        Write-Host "  ⚠️  docker-desktop distro not found" -ForegroundColor Yellow
    }
    
    # Check for Ubuntu distro (needed for NVIDIA Container Toolkit)
    if ($wslList -match "Ubuntu") {
        $ubuntuDistro = ($wslList -split "`n" | Where-Object { $_ -match "Ubuntu" } | Select-Object -First 1)
        Write-Host "  ✅ Ubuntu distro found: $ubuntuDistro" -ForegroundColor Green
    } else {
        $warnings += "No Ubuntu distro found (needed for NVIDIA Container Toolkit)"
        Write-Host "  ⚠️  No Ubuntu distro found" -ForegroundColor Yellow
    }
} catch {
    $warnings += "Could not list WSL distributions: $_"
    Write-Host "  ⚠️  Error listing WSL distributions: $_" -ForegroundColor Yellow
}

# ============================================================================
# 3. Check Docker Desktop Service
# ============================================================================
Write-Host "`n[3/8] Checking Docker Desktop service..." -ForegroundColor Yellow
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    if ($dockerService.Status -eq 'Running') {
        Write-Host "  ✅ Docker Desktop service is running" -ForegroundColor Green
    } else {
        $issues += "Docker Desktop service is not running"
        Write-Host "  ❌ Docker Desktop service is $($dockerService.Status)" -ForegroundColor Red
    }
} else {
    $issues += "Docker Desktop service not found"
    Write-Host "  ❌ Docker Desktop service not found" -ForegroundColor Red
}

# Check Docker Desktop process
$dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerProcess) {
    Write-Host "  ✅ Docker Desktop process is running (PID: $($dockerProcess.Id))" -ForegroundColor Green
    
    # Check CPU usage
    $cpuUsage = ($dockerProcess | Measure-Object CPU -Average).Average
    if ($cpuUsage -gt 50) {
        $warnings += "Docker Desktop CPU usage is high: ${cpuUsage}%"
        Write-Host "  ⚠️  Docker Desktop CPU usage: ${cpuUsage}% (high!)" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ Docker Desktop CPU usage: ${cpuUsage}%" -ForegroundColor Green
    }
} else {
    $warnings += "Docker Desktop GUI process not running"
    Write-Host "  ⚠️  Docker Desktop GUI process not running" -ForegroundColor Yellow
}

# ============================================================================
# 4. Check Docker CLI Availability
# ============================================================================
Write-Host "`n[4/8] Checking Docker CLI..." -ForegroundColor Yellow
try {
    $dockerVersion = docker version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Docker CLI is accessible" -ForegroundColor Green
        $dockerVersion | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
    } else {
        $issues += "Docker CLI not accessible"
        Write-Host "  ❌ Docker CLI not accessible" -ForegroundColor Red
        Write-Host "  Error: $dockerVersion" -ForegroundColor Red
    }
} catch {
    $issues += "Docker CLI error: $_"
    Write-Host "  ❌ Error accessing Docker CLI: $_" -ForegroundColor Red
}

# ============================================================================
# 5. Check Docker Context and Backend
# ============================================================================
Write-Host "`n[5/8] Checking Docker context and backend..." -ForegroundColor Yellow
try {
    $dockerContext = docker context ls 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Docker contexts:" -ForegroundColor Cyan
        Write-Host $dockerContext
    }
    
    $dockerInfo = docker info 2>&1 | Select-Object -First 20
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n  Docker info (first 20 lines):" -ForegroundColor Cyan
        $dockerInfo | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
        
        # Check for WSL2 backend
        $dockerInfoStr = $dockerInfo -join "`n"
        if ($dockerInfoStr -match "OSType.*linux" -or $dockerInfoStr -match "Operating System.*WSL") {
            Write-Host "  ✅ Docker is using WSL2 backend" -ForegroundColor Green
        } else {
            $warnings += "Docker may not be using WSL2 backend"
            Write-Host "  ⚠️  Docker backend unclear from info" -ForegroundColor Yellow
        }
    }
} catch {
    $warnings += "Could not get Docker info: $_"
    Write-Host "  ⚠️  Error getting Docker info: $_" -ForegroundColor Yellow
}

# ============================================================================
# 6. Check NVIDIA Container Toolkit in WSL2
# ============================================================================
Write-Host "`n[6/8] Checking NVIDIA Container Toolkit in WSL2..." -ForegroundColor Yellow

# Find Ubuntu distro
$ubuntuDistro = $null
try {
    $wslList = wsl --list --verbose 2>&1
    $ubuntuLine = ($wslList -split "`n" | Where-Object { $_ -match "Ubuntu" -and $_ -match "Running" } | Select-Object -First 1)
    if ($ubuntuLine) {
        $ubuntuDistro = ($ubuntuLine -split '\s+')[0]
        Write-Host "  Found running Ubuntu distro: $ubuntuDistro" -ForegroundColor Cyan
    } else {
        # Try to find any Ubuntu distro
        $ubuntuLine = ($wslList -split "`n" | Where-Object { $_ -match "Ubuntu" } | Select-Object -First 1)
        if ($ubuntuLine) {
            $ubuntuDistro = ($ubuntuLine -split '\s+')[0]
            Write-Host "  Found Ubuntu distro (not running): $ubuntuDistro" -ForegroundColor Yellow
            Write-Host "  Starting Ubuntu distro..." -ForegroundColor Yellow
            wsl -d $ubuntuDistro -- echo "Starting" 2>&1 | Out-Null
            Start-Sleep -Seconds 3
        }
    }
} catch {
    Write-Host "  ⚠️  Could not find Ubuntu distro: $_" -ForegroundColor Yellow
}

if ($ubuntuDistro) {
    Write-Host "  Checking NVIDIA Container Toolkit installation..." -ForegroundColor Cyan
    try {
        # Check if nvidia-container-toolkit is installed
        $nvidiaToolkitCheck = wsl -d $ubuntuDistro -- bash -c "dpkg -l | grep nvidia-container-toolkit" 2>&1
        if ($LASTEXITCODE -eq 0 -and $nvidiaToolkitCheck) {
            Write-Host "  ✅ NVIDIA Container Toolkit is installed" -ForegroundColor Green
            Write-Host "  $nvidiaToolkitCheck" -ForegroundColor Cyan
        } else {
            $issues += "NVIDIA Container Toolkit not installed in WSL2"
            Write-Host "  ❌ NVIDIA Container Toolkit NOT installed in WSL2" -ForegroundColor Red
            Write-Host "  This is required for GPU access in Docker containers!" -ForegroundColor Red
        }
        
        # Check nvidia-container-runtime
        $nvidiaRuntimeCheck = wsl -d $ubuntuDistro -- bash -c "which nvidia-container-runtime" 2>&1
        if ($LASTEXITCODE -eq 0 -and $nvidiaRuntimeCheck) {
            Write-Host "  ✅ nvidia-container-runtime found" -ForegroundColor Green
        } else {
            $warnings += "nvidia-container-runtime not found"
            Write-Host "  ⚠️  nvidia-container-runtime not found" -ForegroundColor Yellow
        }
        
        # Check Docker daemon.json for NVIDIA runtime
        $dockerDaemonCheck = wsl -d $ubuntuDistro -- bash -c "cat /etc/docker/daemon.json 2>/dev/null || echo 'daemon.json not found'" 2>&1
        if ($dockerDaemonCheck -match "nvidia") {
            Write-Host "  ✅ Docker daemon.json contains NVIDIA runtime config" -ForegroundColor Green
            Write-Host "  $dockerDaemonCheck" -ForegroundColor Cyan
        } else {
            $warnings += "Docker daemon.json may not have NVIDIA runtime configured"
            Write-Host "  ⚠️  Docker daemon.json may not have NVIDIA runtime configured" -ForegroundColor Yellow
        }
        
        # Check if GPU is visible in WSL2
        $wslGpuCheck = wsl -d $ubuntuDistro -- bash -c "nvidia-smi 2>&1" 2>&1
        if ($LASTEXITCODE -eq 0 -and $wslGpuCheck -match "NVIDIA") {
            Write-Host "  ✅ GPU is visible in WSL2" -ForegroundColor Green
        } else {
            $issues += "GPU not visible in WSL2"
            Write-Host "  ❌ GPU not visible in WSL2" -ForegroundColor Red
            Write-Host "  Output: $wslGpuCheck" -ForegroundColor Red
        }
    } catch {
        $warnings += "Could not check NVIDIA Container Toolkit: $_"
        Write-Host "  ⚠️  Error checking NVIDIA Container Toolkit: $_" -ForegroundColor Yellow
    }
} else {
    $warnings += "No Ubuntu distro available to check NVIDIA Container Toolkit"
    Write-Host "  ⚠️  No Ubuntu distro found - cannot check NVIDIA Container Toolkit" -ForegroundColor Yellow
}

# ============================================================================
# 7. Test Docker GPU Support
# ============================================================================
Write-Host "`n[7/8] Testing Docker GPU support..." -ForegroundColor Yellow
try {
    # Try to run a simple GPU test container
    Write-Host "  Testing with nvidia/cuda:11.0.3-base-ubuntu20.04..." -ForegroundColor Cyan
    $gpuTest = docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi 2>&1
    if ($LASTEXITCODE -eq 0 -and $gpuTest -match "NVIDIA") {
        Write-Host "  ✅ Docker GPU support is working!" -ForegroundColor Green
        Write-Host "  GPU Test Output:" -ForegroundColor Cyan
        $gpuTest | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
    } else {
        $issues += "Docker GPU support not working"
        Write-Host "  ❌ Docker GPU support NOT working" -ForegroundColor Red
        Write-Host "  Error output:" -ForegroundColor Red
        $gpuTest | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} catch {
    $issues += "Docker GPU test failed: $_"
    Write-Host "  ❌ Docker GPU test failed: $_" -ForegroundColor Red
}

# ============================================================================
# 8. Check vLLM Container Status
# ============================================================================
Write-Host "`n[8/8] Checking vLLM container status..." -ForegroundColor Yellow
try {
    $formatString = '{{.Names}}\t{{.Status}}\t{{.Ports}}'
    $vllmContainer = docker ps -a --filter "name=vllm-armitage" --format $formatString 2>&1
    if ($LASTEXITCODE -eq 0 -and $vllmContainer) {
        Write-Host "  vLLM container found:" -ForegroundColor Cyan
        Write-Host "  $vllmContainer" -ForegroundColor Cyan
        if ($vllmContainer -match "Up") {
            Write-Host "  ✅ vLLM container is running" -ForegroundColor Green
            
            # Check logs for GPU errors
            Write-Host "`n  Checking container logs for GPU errors..." -ForegroundColor Cyan
            $logs = docker logs vllm-armitage --tail 50 2>&1
            if ($logs -match "CUDA|GPU|nvidia" -and $logs -match "error|Error|ERROR|failed|Failed") {
                $warnings += "vLLM container logs show GPU-related errors"
                Write-Host "  ⚠️  GPU-related errors found in logs:" -ForegroundColor Yellow
                ($logs | Select-String -Pattern "error|Error|ERROR|failed|Failed" | Select-Object -First 5) | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
            } else {
                Write-Host "  ✅ No obvious GPU errors in recent logs" -ForegroundColor Green
            }
        } else {
            Write-Host "  ⚠️  vLLM container exists but is not running" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ℹ️  vLLM container not found (may not have been started yet)" -ForegroundColor Cyan
    }
} catch {
    $warnings += "Could not check vLLM container: $_"
    Write-Host "  ⚠️  Error checking vLLM container: $_" -ForegroundColor Yellow
}

# ============================================================================
# Summary and Recommendations
# ============================================================================
Write-Host "`n" -NoNewline
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Summary                                                    ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "`n✅ All checks passed! Docker + NVIDIA setup looks good." -ForegroundColor Green
} else {
    if ($issues.Count -gt 0) {
        Write-Host "`n❌ Critical Issues Found ($($issues.Count)):" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host "`n⚠️  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
        $warnings | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
    }
}

Write-Host "`n📋 Recommendations:" -ForegroundColor Cyan

if ($issues -match "NVIDIA Container Toolkit") {
    $recommendation = @"
  
  🔧 Install NVIDIA Container Toolkit in WSL2:
  
  1. Open WSL2 Ubuntu:
     wsl -d Ubuntu-22.04
  
  2. Run these commands:
     distribution=`$(. /etc/os-release;echo `$ID`$VERSION_ID)
     curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
     curl -s -L https://nvidia.github.io/libnvidia-container/`$distribution/libnvidia-container.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
     sudo apt-get update
     sudo apt-get install -y nvidia-container-toolkit
     sudo nvidia-ctk runtime configure --runtime=docker
     sudo systemctl restart docker
  
  3. Note: Docker Desktop uses its own Docker daemon, so restart Docker Desktop
     after installing the toolkit.
"@
    Write-Host $recommendation -ForegroundColor Yellow
}

if ($warnings -match "CPU usage") {
    $cpuFix = @"
  
  🔧 Fix Docker Desktop High CPU Usage:
  
  1. Open Docker Desktop Settings
  2. Go to Resources > Advanced
  3. Reduce CPU limit if set too high
  4. Go to General > Uncheck "Use WSL 2 based engine" then re-enable it
  5. Restart Docker Desktop
  
  Or try:
  - Restart Docker Desktop completely
  - Check for Docker Desktop updates
  - Restart WSL2: wsl --shutdown
"@
    Write-Host $cpuFix -ForegroundColor Yellow
}

if ($issues -match "GPU not visible in WSL2") {
    $gpuFix = @"
  
  🔧 Fix GPU Visibility in WSL2:
  
  1. Ensure NVIDIA drivers are up to date on Windows
  2. Install WSL2 CUDA drivers from NVIDIA:
     https://developer.nvidia.com/cuda/wsl
  3. Restart WSL2: wsl --shutdown
  4. Restart Docker Desktop
"@
    Write-Host $gpuFix -ForegroundColor Yellow
}

Write-Host "`n💡 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Fix any critical issues listed above" -ForegroundColor White
Write-Host "  2. Run this script again to verify fixes" -ForegroundColor White
Write-Host "  3. Test vLLM container: .\Start-VLLM.ps1 -Action Start" -ForegroundColor White
Write-Host "  4. Check logs: .\Start-VLLM.ps1 -Action Logs" -ForegroundColor White

Write-Host "`n"

