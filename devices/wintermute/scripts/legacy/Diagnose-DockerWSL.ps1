<#
.SYNOPSIS
    Comprehensive diagnostic script for Docker Desktop and WSL2 on Wintermute
.DESCRIPTION
    Checks all aspects of Docker Desktop + WSL2 + NVIDIA GPU configuration
    and provides actionable recommendations
.EXAMPLE
    .\Diagnose-DockerWSL.ps1
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"
$script:issues = @()
$script:warnings = @()
$script:success = @()

function Write-Check {
    param([string]$Message, [string]$Status)
    
    $icon = switch ($Status) {
        "OK" { "✅"; $script:success += $Message; $color = "Green" }
        "WARNING" { "⚠️"; $script:warnings += $Message; $color = "Yellow" }
        "ERROR" { "❌"; $script:issues += $Message; $color = "Red" }
        default { "ℹ️"; $color = "Cyan" }
    }
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Wintermute Docker + WSL2 + NVIDIA Diagnostic Tool" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Current User and Profile
Write-Host "[1/15] Checking Current User..." -ForegroundColor Cyan
$currentUser = $env:USERNAME
$userProfile = $env:USERPROFILE
Write-Check "Current user: $currentUser" "INFO"
Write-Check "User profile: $userProfile" "INFO"

if ($currentUser -eq "mdt") {
    Write-Check "Running as 'mdt' local account" "OK"
} else {
    Write-Check "Not running as 'mdt' - expected local account" "WARNING"
}

# Check 2: WSL Installation
Write-Host "`n[2/15] Checking WSL Installation..." -ForegroundColor Cyan
try {
    $wslVersion = wsl --version 2>&1 | Out-String
    Write-Check "WSL is installed" "OK"
} catch {
    Write-Check "WSL is not installed or not accessible" "ERROR"
}

# Check 3: WSL Distributions
Write-Host "`n[3/15] Checking WSL Distributions..." -ForegroundColor Cyan
try {
    $wslList = wsl --list --verbose 2>&1 | Out-String
    Write-Host $wslList
    
    $hasUbuntu2404 = $wslList -match "Ubuntu-24\.04"
    $hasUbuntu2204 = $wslList -match "Ubuntu-22\.04"
    
    if ($hasUbuntu2404) {
        Write-Check "Ubuntu 24.04 is installed" "OK"
        
        # Check if it's WSL2
        if ($wslList -match "Ubuntu-24\.04.*2") {
            Write-Check "Ubuntu 24.04 is using WSL2" "OK"
        } else {
            Write-Check "Ubuntu 24.04 is NOT using WSL2 - needs conversion" "ERROR"
        }
    } else {
        Write-Check "Ubuntu 24.04 is NOT installed" "ERROR"
    }
    
    if ($hasUbuntu2204) {
        Write-Check "Ubuntu 22.04 is still installed - should be removed" "WARNING"
    } else {
        Write-Check "Ubuntu 22.04 not present (good - we want only 24.04)" "OK"
    }
    
    # Check default distro
    $defaultDistro = (wsl --list --verbose 2>&1 | Select-String "\*" | Out-String).Trim()
    if ($defaultDistro -match "Ubuntu-24\.04") {
        Write-Check "Ubuntu 24.04 is the default WSL distribution" "OK"
    } else {
        Write-Check "Ubuntu 24.04 is NOT the default distribution" "WARNING"
    }
} catch {
    Write-Check "Failed to check WSL distributions" "ERROR"
}

# Check 4: Windows Features
Write-Host "`n[4/15] Checking Windows Features..." -ForegroundColor Cyan
try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    if ($wslFeature.State -eq "Enabled") {
        Write-Check "WSL feature is enabled" "OK"
    } else {
        Write-Check "WSL feature is NOT enabled" "ERROR"
    }
    
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    if ($vmFeature.State -eq "Enabled") {
        Write-Check "Virtual Machine Platform is enabled" "OK"
    } else {
        Write-Check "Virtual Machine Platform is NOT enabled" "ERROR"
    }
} catch {
    Write-Check "Failed to check Windows features" "ERROR"
}

# Check 5: Docker Desktop Installation
Write-Host "`n[5/15] Checking Docker Desktop Installation..." -ForegroundColor Cyan
$dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerExe) {
    Write-Check "Docker Desktop executable found" "OK"
} else {
    Write-Check "Docker Desktop executable NOT found" "ERROR"
}

# Check 6: Docker Service
Write-Host "`n[6/15] Checking Docker Service..." -ForegroundColor Cyan
try {
    $dockerService = Get-Service com.docker.service -ErrorAction SilentlyContinue
    if ($dockerService) {
        if ($dockerService.Status -eq "Running") {
            Write-Check "Docker service is running" "OK"
        } else {
            Write-Check "Docker service exists but is NOT running (Status: $($dockerService.Status))" "ERROR"
        }
    } else {
        Write-Check "Docker service not found" "ERROR"
    }
} catch {
    Write-Check "Failed to check Docker service" "ERROR"
}

# Check 7: Docker Desktop Process
Write-Host "`n[7/15] Checking Docker Desktop Process..." -ForegroundColor Cyan
$dockerProcesses = Get-Process "*docker*" -ErrorAction SilentlyContinue
if ($dockerProcesses) {
    Write-Check "Docker Desktop processes are running" "OK"
    foreach ($proc in $dockerProcesses) {
        Write-Host "   - $($proc.ProcessName) (PID: $($proc.Id), CPU: $($proc.CPU))" -ForegroundColor Gray
    }
} else {
    Write-Check "No Docker Desktop processes found" "WARNING"
}

# Check 8: Docker CLI Accessibility
Write-Host "`n[8/15] Checking Docker CLI..." -ForegroundColor Cyan
try {
    $dockerVersion = docker version 2>&1 | Out-String
    if ($dockerVersion -match "Server:" -and $dockerVersion -match "Client:") {
        Write-Check "Docker CLI is working (both client and server)" "OK"
    } elseif ($dockerVersion -match "Client:") {
        Write-Check "Docker CLI client works but server is not responding" "ERROR"
        Write-Host $dockerVersion -ForegroundColor Gray
    } else {
        Write-Check "Docker CLI is not accessible" "ERROR"
    }
} catch {
    Write-Check "Failed to run docker CLI" "ERROR"
}

# Check 9: Docker Configuration
Write-Host "`n[9/15] Checking Docker Desktop Configuration..." -ForegroundColor Cyan
$dockerConfigPath = "$env:USERPROFILE\.docker\settings.json"
if (Test-Path $dockerConfigPath) {
    Write-Check "Docker settings file exists" "OK"
    
    try {
        $dockerConfig = Get-Content $dockerConfigPath | ConvertFrom-Json
        
        if ($dockerConfig.wslEngineEnabled) {
            Write-Check "WSL2 engine is enabled in Docker settings" "OK"
        } else {
            Write-Check "WSL2 engine is NOT enabled in Docker settings" "ERROR"
        }
        
        Write-Host "   Current settings:" -ForegroundColor Gray
        $dockerConfig | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Gray
    } catch {
        Write-Check "Failed to parse Docker settings file" "WARNING"
    }
} else {
    Write-Check "Docker settings file does NOT exist - needs creation" "ERROR"
}

# Check 10: NVIDIA Drivers on Windows
Write-Host "`n[10/15] Checking NVIDIA Drivers (Windows)..." -ForegroundColor Cyan
try {
    $nvidiaSmi = nvidia-smi 2>&1 | Out-String
    if ($nvidiaSmi -match "RTX 4070") {
        Write-Check "NVIDIA GPU detected (RTX 4070 Super)" "OK"
        # Show driver version
        if ($nvidiaSmi -match "Driver Version: ([\d\.]+)") {
            Write-Host "   Driver Version: $($matches[1])" -ForegroundColor Gray
        }
    } else {
        Write-Check "NVIDIA GPU not detected or nvidia-smi failed" "ERROR"
    }
} catch {
    Write-Check "Failed to run nvidia-smi on Windows" "ERROR"
}

# Check 11: NVIDIA in WSL
Write-Host "`n[11/15] Checking NVIDIA in WSL2..." -ForegroundColor Cyan
try {
    $wslNvidia = wsl -d Ubuntu-24.04 -- nvidia-smi 2>&1 | Out-String
    if ($wslNvidia -match "NVIDIA") {
        Write-Check "NVIDIA GPU accessible from WSL2" "OK"
    } else {
        Write-Check "NVIDIA GPU NOT accessible from WSL2" "ERROR"
    }
} catch {
    Write-Check "Failed to check NVIDIA in WSL2 (is Ubuntu 24.04 installed?)" "ERROR"
}

# Check 12: NVIDIA Container Toolkit in WSL
Write-Host "`n[12/15] Checking NVIDIA Container Toolkit in WSL2..." -ForegroundColor Cyan
try {
    $nvidiaToolkit = wsl -d Ubuntu-24.04 -- dpkg -l nvidia-container-toolkit 2>&1 | Out-String
    if ($nvidiaToolkit -match "ii.*nvidia-container-toolkit") {
        Write-Check "NVIDIA Container Toolkit is installed in WSL2" "OK"
    } else {
        Write-Check "NVIDIA Container Toolkit is NOT installed in WSL2" "ERROR"
    }
} catch {
    Write-Check "Failed to check NVIDIA Container Toolkit in WSL2" "ERROR"
}

# Check 13: Docker GPU Support
Write-Host "`n[13/15] Testing Docker GPU Support..." -ForegroundColor Cyan
try {
    Write-Host "   Running test container (may take 30 seconds)..." -ForegroundColor Gray
    $gpuTest = docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi 2>&1 | Out-String
    if ($gpuTest -match "RTX 4070") {
        Write-Check "Docker can access GPU successfully" "OK"
    } else {
        Write-Check "Docker CANNOT access GPU" "ERROR"
        Write-Host $gpuTest -ForegroundColor Gray
    }
} catch {
    Write-Check "Failed to test Docker GPU support" "ERROR"
}

# Check 14: vLLM Container
Write-Host "`n[14/15] Checking vLLM Container..." -ForegroundColor Cyan
try {
    $vllmContainer = docker ps --filter name=vllm-wintermute 2>&1 | Out-String
    if ($vllmContainer -match "vllm-wintermute") {
        Write-Check "vLLM container is running" "OK"
    } else {
        # Check if it exists but is stopped
        $vllmContainerAll = docker ps -a --filter name=vllm-wintermute 2>&1 | Out-String
        if ($vllmContainerAll -match "vllm-wintermute") {
            Write-Check "vLLM container exists but is NOT running" "WARNING"
        } else {
            Write-Check "vLLM container does NOT exist" "WARNING"
        }
    }
} catch {
    Write-Check "Failed to check vLLM container" "ERROR"
}

# Check 15: vLLM API Endpoint
Write-Host "`n[15/15] Testing vLLM API Endpoint..." -ForegroundColor Cyan
try {
    $vllmHealth = curl http://localhost:8000/health 2>&1 | Out-String
    if ($vllmHealth -match "healthy" -or $vllmHealth -match "200") {
        Write-Check "vLLM API is responding" "OK"
    } else {
        Write-Check "vLLM API is NOT responding" "WARNING"
    }
} catch {
    Write-Check "Failed to test vLLM API endpoint" "WARNING"
}

# Summary
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC SUMMARY" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Success: $($script:success.Count)" -ForegroundColor Green
Write-Host "⚠️  Warnings: $($script:warnings.Count)" -ForegroundColor Yellow
Write-Host "❌ Errors: $($script:issues.Count)" -ForegroundColor Red
Write-Host ""

if ($script:issues.Count -gt 0) {
    Write-Host "CRITICAL ISSUES:" -ForegroundColor Red
    foreach ($issue in $script:issues) {
        Write-Host "  ❌ $issue" -ForegroundColor Red
    }
    Write-Host ""
}

if ($script:warnings.Count -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $script:warnings) {
        Write-Host "  ⚠️  $warning" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Recommendations
Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Cyan
Write-Host ""

if ($script:issues -match "WSL2 engine is NOT enabled") {
    Write-Host "1. Enable WSL2 in Docker Desktop:" -ForegroundColor Yellow
    Write-Host "   - Open Docker Desktop Settings > General" -ForegroundColor White
    Write-Host "   - Check 'Use WSL 2 based engine'" -ForegroundColor White
    Write-Host ""
}

if ($script:issues -match "Ubuntu 24.04 is NOT installed" -or $script:issues -match "Ubuntu 24.04 is NOT using WSL2") {
    Write-Host "2. Install/Fix Ubuntu 24.04:" -ForegroundColor Yellow
    Write-Host "   wsl --install -d Ubuntu-24.04" -ForegroundColor White
    Write-Host "   wsl --set-version Ubuntu-24.04 2" -ForegroundColor White
    Write-Host "   wsl --set-default Ubuntu-24.04" -ForegroundColor White
    Write-Host ""
}

if ($script:warnings -match "Ubuntu 22.04 is still installed") {
    Write-Host "3. Remove Ubuntu 22.04:" -ForegroundColor Yellow
    Write-Host "   wsl --shutdown" -ForegroundColor White
    Write-Host "   wsl --unregister Ubuntu-22.04" -ForegroundColor White
    Write-Host ""
}

if ($script:issues -match "NVIDIA Container Toolkit is NOT installed") {
    Write-Host "4. Install NVIDIA Container Toolkit in WSL2:" -ForegroundColor Yellow
    Write-Host "   wsl -d Ubuntu-24.04" -ForegroundColor White
    Write-Host "   # Then run installation commands inside WSL" -ForegroundColor White
    Write-Host ""
}

if ($script:issues -match "Docker service.*NOT running") {
    Write-Host "5. Start Docker Desktop:" -ForegroundColor Yellow
    Write-Host "   Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor White
    Write-Host ""
}

if ($script:issues -match "Docker settings file does NOT exist") {
    Write-Host "6. Create Docker settings file:" -ForegroundColor Yellow
    Write-Host "   See docs/runbooks/wintermute-docker-rebuild.md" -ForegroundColor White
    Write-Host ""
}

Write-Host "For detailed troubleshooting, see:" -ForegroundColor Cyan
Write-Host "  docs/runbooks/wintermute-docker-rebuild.md" -ForegroundColor White
Write-Host ""



