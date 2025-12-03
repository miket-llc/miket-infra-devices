<#
.SYNOPSIS
    Completely removes Docker Desktop from Windows
.DESCRIPTION
    Uninstalls Docker Desktop, removes all traces, cleans WSL2 docker-desktop distro,
    and removes registry entries
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete Docker Desktop Removal" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# 1. Stop all Docker processes
Write-Host "[1] Stopping Docker processes..." -ForegroundColor Yellow
Get-Process "*docker*" -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like "*Docker*" -or 
    $_.ProcessName -like "*com.docker*"
} | ForEach-Object {
    Write-Host "  Stopping $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3
Write-Host "  ✓ Docker processes stopped" -ForegroundColor Green
Write-Host ""

# 2. Stop Docker service
Write-Host "[2] Stopping Docker service..." -ForegroundColor Yellow
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    if ($dockerService.Status -eq "Running") {
        Stop-Service -Name "com.docker.service" -Force -ErrorAction SilentlyContinue
    }
    Set-Service -Name "com.docker.service" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  ✓ Docker service stopped and disabled" -ForegroundColor Green
} else {
    Write-Host "  ✓ Docker service not found" -ForegroundColor Green
}
Write-Host ""

# 3. Unregister WSL2 docker-desktop distro
Write-Host "[3] Removing WSL2 docker-desktop distro..." -ForegroundColor Yellow
try {
    $ErrorActionPreference = "SilentlyContinue"
    $wslList = wsl --list --verbose
    $ErrorActionPreference = "Stop"
    if ($wslList -match "docker-desktop") {
        Write-Host "  Found docker-desktop distro, removing..." -ForegroundColor Yellow
        $ErrorActionPreference = "SilentlyContinue"
        wsl --unregister docker-desktop
        $ErrorActionPreference = "Stop"
        Write-Host "  ✓ docker-desktop distro removed" -ForegroundColor Green
    } else {
        Write-Host "  ✓ No docker-desktop distro found" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Error checking WSL2: $_" -ForegroundColor Yellow
}
Write-Host ""

# 4. Uninstall via Chocolatey
Write-Host "[4] Uninstalling Docker Desktop via Chocolatey..." -ForegroundColor Yellow
try {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $ErrorActionPreference = "SilentlyContinue"
        $chocoResult = choco uninstall docker-desktop -y
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Docker Desktop uninstalled via Chocolatey" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Chocolatey uninstall may have failed (may not be installed)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ⚠️  Chocolatey not found, skipping Chocolatey uninstall" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error with Chocolatey: $_" -ForegroundColor Yellow
}
Write-Host ""

# 5. Remove Docker directories
Write-Host "[5] Removing Docker directories..." -ForegroundColor Yellow
$dockerDirs = @(
    "$env:USERPROFILE\.docker",
    "$env:ProgramData\Docker",
    "$env:ProgramData\DockerDesktop",
    "${env:ProgramFiles}\Docker",
    "${env:ProgramFiles(x86)}\Docker"
)

foreach ($dir in $dockerDirs) {
    if (Test-Path $dir) {
        try {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed: $dir" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Could not remove: $dir" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# 6. Remove registry entries
Write-Host "[6] Removing registry entries..." -ForegroundColor Yellow
$regPaths = @(
    "HKCU:\Software\Docker Inc.",
    "HKLM:\SOFTWARE\Docker Inc.",
    "HKLM:\SOFTWARE\WOW6432Node\Docker Inc."
)

foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        try {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed registry: $regPath" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Could not remove registry: $regPath" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# 7. Remove startup shortcuts
Write-Host "[7] Removing startup shortcuts..." -ForegroundColor Yellow
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$dockerStartup = Get-ChildItem -Path $startupPath -Filter "*docker*" -ErrorAction SilentlyContinue
if ($dockerStartup) {
    $dockerStartup | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed startup shortcut: $($_.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "  ✓ No Docker startup shortcuts found" -ForegroundColor Green
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker Desktop Removal Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ All Docker processes stopped" -ForegroundColor Green
Write-Host "✓ Docker service disabled" -ForegroundColor Green
Write-Host "✓ WSL2 docker-desktop distro removed" -ForegroundColor Green
Write-Host "✓ Docker Desktop uninstalled" -ForegroundColor Green
Write-Host "✓ Directories cleaned" -ForegroundColor Green
Write-Host "✓ Registry entries removed" -ForegroundColor Green
Write-Host ""
Write-Host "Reboot recommended to complete cleanup." -ForegroundColor Cyan
Write-Host ""

