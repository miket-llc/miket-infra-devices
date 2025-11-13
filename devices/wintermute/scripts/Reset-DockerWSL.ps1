<#
.SYNOPSIS
    Quick reset and fix script for Docker Desktop + WSL2 on Wintermute
.DESCRIPTION
    Performs automated cleanup and reconfiguration of Docker Desktop and WSL2:
    - Stops Docker Desktop
    - Removes Ubuntu 22.04 (if present)
    - Ensures Ubuntu 24.04 is installed and configured
    - Configures Docker Desktop for WSL2 backend
    - Restarts Docker Desktop
.EXAMPLE
    .\Reset-DockerWSL.ps1
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Wintermute Docker + WSL2 Reset Script" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  1. Stop Docker Desktop" -ForegroundColor White
Write-Host "  2. Shutdown WSL" -ForegroundColor White
Write-Host "  3. Remove Ubuntu 22.04 (if present)" -ForegroundColor White
Write-Host "  4. Install/Configure Ubuntu 24.04" -ForegroundColor White
Write-Host "  5. Configure Docker Desktop for WSL2" -ForegroundColor White
Write-Host "  6. Restart Docker Desktop" -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Continue? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Aborted by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Step 1: Stop Docker Desktop
Write-Host "[Step 1/6] Stopping Docker Desktop..." -ForegroundColor Cyan
try {
    # Stop Docker Desktop GUI
    $dockerProcesses = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
    if ($dockerProcesses) {
        Write-Host "  Stopping Docker Desktop processes..." -ForegroundColor Yellow
        Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
    }
    
    # Stop Docker service
    $dockerService = Get-Service com.docker.service -ErrorAction SilentlyContinue
    if ($dockerService -and $dockerService.Status -eq "Running") {
        Write-Host "  Stopping Docker service..." -ForegroundColor Yellow
        Stop-Service com.docker.service -Force -ErrorAction SilentlyContinue
    }
    
    Start-Sleep -Seconds 5
    Write-Host "  ✅ Docker Desktop stopped" -ForegroundColor Green
} catch {
    Write-Warning "  Failed to stop Docker Desktop (may not be running): $_"
}

# Step 2: Shutdown WSL
Write-Host "`n[Step 2/6] Shutting down WSL..." -ForegroundColor Cyan
try {
    wsl --shutdown
    Start-Sleep -Seconds 3
    Write-Host "  ✅ WSL shutdown complete" -ForegroundColor Green
} catch {
    Write-Warning "  Failed to shutdown WSL: $_"
}

# Step 3: Remove Ubuntu 22.04
Write-Host "`n[Step 3/6] Checking for Ubuntu 22.04..." -ForegroundColor Cyan
try {
    $wslList = wsl --list --quiet 2>&1 | Out-String
    
    if ($wslList -match "Ubuntu-22.04") {
        Write-Host "  Ubuntu 22.04 found - removing..." -ForegroundColor Yellow
        Write-Host "  ⚠️  This will delete all data in Ubuntu 22.04" -ForegroundColor Red
        
        $removeConfirm = Read-Host "  Remove Ubuntu 22.04? (yes/no)"
        if ($removeConfirm -eq "yes") {
            wsl --unregister Ubuntu-22.04
            Write-Host "  ✅ Ubuntu 22.04 removed" -ForegroundColor Green
        } else {
            Write-Host "  ⏭️  Skipped Ubuntu 22.04 removal" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✅ Ubuntu 22.04 not present (good)" -ForegroundColor Green
    }
} catch {
    Write-Warning "  Failed to check/remove Ubuntu 22.04: $_"
}

# Step 4: Install/Configure Ubuntu 24.04
Write-Host "`n[Step 4/6] Configuring Ubuntu 24.04..." -ForegroundColor Cyan
try {
    $wslList = wsl --list --quiet 2>&1 | Out-String
    
    if ($wslList -notmatch "Ubuntu-24.04") {
        Write-Host "  Ubuntu 24.04 not found - installing..." -ForegroundColor Yellow
        wsl --install -d Ubuntu-24.04 --no-launch
        Write-Host "  ✅ Ubuntu 24.04 installed" -ForegroundColor Green
        Write-Host "  ℹ️  You'll need to complete first-run setup: wsl -d Ubuntu-24.04" -ForegroundColor Cyan
    } else {
        Write-Host "  ✅ Ubuntu 24.04 already installed" -ForegroundColor Green
    }
    
    # Ensure it's WSL2
    Write-Host "  Setting Ubuntu 24.04 to WSL2..." -ForegroundColor Yellow
    wsl --set-version Ubuntu-24.04 2 2>&1 | Out-Null
    
    # Set as default
    Write-Host "  Setting Ubuntu 24.04 as default..." -ForegroundColor Yellow
    wsl --set-default Ubuntu-24.04 2>&1 | Out-Null
    
    Write-Host "  ✅ Ubuntu 24.04 configured as default WSL2 distribution" -ForegroundColor Green
    
} catch {
    Write-Warning "  Failed to configure Ubuntu 24.04: $_"
}

# Step 5: Configure Docker Desktop
Write-Host "`n[Step 5/6] Configuring Docker Desktop settings..." -ForegroundColor Cyan
try {
    $dockerConfigDir = "$env:USERPROFILE\.docker"
    $dockerConfigPath = "$dockerConfigDir\settings.json"
    
    # Ensure directory exists
    if (-not (Test-Path $dockerConfigDir)) {
        Write-Host "  Creating Docker config directory..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $dockerConfigDir -Force | Out-Null
    }
    
    # Backup existing settings
    if (Test-Path $dockerConfigPath) {
        $backupPath = "$dockerConfigPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Host "  Backing up existing settings to: $backupPath" -ForegroundColor Yellow
        Copy-Item $dockerConfigPath $backupPath
    }
    
    # Create/Update settings
    $dockerSettings = @{
        wslEngineEnabled = $true
        displayedOnboarding = $true
    }
    
    # If existing settings, merge with WSL2 enabled
    if (Test-Path $dockerConfigPath) {
        try {
            $existingSettings = Get-Content $dockerConfigPath | ConvertFrom-Json
            $existingSettings.wslEngineEnabled = $true
            $existingSettings | ConvertTo-Json -Depth 10 | Set-Content $dockerConfigPath -Encoding UTF8
            Write-Host "  ✅ Updated existing Docker settings for WSL2" -ForegroundColor Green
        } catch {
            # If parsing fails, create new settings
            $dockerSettings | ConvertTo-Json -Depth 10 | Set-Content $dockerConfigPath -Encoding UTF8
            Write-Host "  ✅ Created new Docker settings for WSL2" -ForegroundColor Green
        }
    } else {
        $dockerSettings | ConvertTo-Json -Depth 10 | Set-Content $dockerConfigPath -Encoding UTF8
        Write-Host "  ✅ Created Docker settings for WSL2" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "  Failed to configure Docker Desktop settings: $_"
}

# Step 6: Start Docker Desktop
Write-Host "`n[Step 6/6] Starting Docker Desktop..." -ForegroundColor Cyan
try {
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    
    if (Test-Path $dockerExe) {
        Write-Host "  Launching Docker Desktop..." -ForegroundColor Yellow
        Start-Process $dockerExe
        Write-Host "  ✅ Docker Desktop started" -ForegroundColor Green
        Write-Host "  ⏳ Docker Desktop is initializing (may take 1-2 minutes)..." -ForegroundColor Cyan
    } else {
        Write-Warning "  Docker Desktop executable not found at: $dockerExe"
        Write-Host "  You may need to reinstall Docker Desktop" -ForegroundColor Yellow
    }
} catch {
    Write-Warning "  Failed to start Docker Desktop: $_"
}

# Summary
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Reset Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Wait for Docker Desktop to finish initializing (1-2 min)" -ForegroundColor Yellow
Write-Host "   - Watch system tray for Docker icon to become solid" -ForegroundColor White
Write-Host ""
Write-Host "2. Verify Docker is working:" -ForegroundColor Yellow
Write-Host "   docker version" -ForegroundColor White
Write-Host "   docker run hello-world" -ForegroundColor White
Write-Host ""
Write-Host "3. If Ubuntu 24.04 is newly installed, complete first-run setup:" -ForegroundColor Yellow
Write-Host "   wsl -d Ubuntu-24.04" -ForegroundColor White
Write-Host "   # Follow prompts to create username (suggest: mdt) and password" -ForegroundColor White
Write-Host ""
Write-Host "4. Install NVIDIA Container Toolkit in WSL2:" -ForegroundColor Yellow
Write-Host "   See: docs/runbooks/wintermute-docker-rebuild.md" -ForegroundColor White
Write-Host "   Or run: .\Install-NvidiaContainerToolkit.ps1" -ForegroundColor White
Write-Host ""
Write-Host "5. Run diagnostic to verify everything:" -ForegroundColor Yellow
Write-Host "   .\Diagnose-DockerWSL.ps1" -ForegroundColor White
Write-Host ""
Write-Host "For detailed troubleshooting, see:" -ForegroundColor Cyan
Write-Host "  docs/runbooks/wintermute-docker-rebuild.md" -ForegroundColor White
Write-Host ""



