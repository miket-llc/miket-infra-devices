<#
.SYNOPSIS
    Stops Docker Desktop completely and prevents it from auto-starting
.DESCRIPTION
    Stops all Docker Desktop processes and services, and disables auto-start
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Stopping Docker Desktop" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# 1. Stop Docker Desktop GUI process
Write-Host "[1] Stopping Docker Desktop GUI..." -ForegroundColor Yellow
$dockerProcesses = Get-Process "*docker*" -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like "*Docker*" -or 
    $_.ProcessName -like "*com.docker*"
}
if ($dockerProcesses) {
    Write-Host "  Found Docker processes:" -ForegroundColor Cyan
    $dockerProcesses | ForEach-Object {
        Write-Host "    $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  ✓ Docker Desktop processes stopped" -ForegroundColor Green
} else {
    Write-Host "  ✓ No Docker Desktop processes running" -ForegroundColor Green
}
Write-Host ""

# 2. Stop Docker service
Write-Host "[2] Stopping Docker service..." -ForegroundColor Yellow
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    if ($dockerService.Status -eq "Running") {
        Stop-Service -Name "com.docker.service" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "  ✓ Docker service stopped" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Docker service already stopped" -ForegroundColor Green
    }
    
    # Disable auto-start
    Set-Service -Name "com.docker.service" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  ✓ Docker service auto-start disabled" -ForegroundColor Green
} else {
    Write-Host "  ✓ Docker service not found" -ForegroundColor Green
}
Write-Host ""

# 3. Check for Docker Desktop in startup
Write-Host "[3] Checking startup programs..." -ForegroundColor Yellow
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$dockerStartup = Get-ChildItem -Path $startupPath -Filter "*docker*" -ErrorAction SilentlyContinue
if ($dockerStartup) {
    Write-Host "  ⚠️  Found Docker startup shortcuts:" -ForegroundColor Yellow
    $dockerStartup | ForEach-Object {
        Write-Host "    $($_.Name)" -ForegroundColor Gray
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  ✓ Removed Docker startup shortcuts" -ForegroundColor Green
} else {
    Write-Host "  ✓ No Docker startup shortcuts found" -ForegroundColor Green
}
Write-Host ""

# 4. Check WSL2 docker-desktop distro
Write-Host "[4] Checking WSL2 docker-desktop distro..." -ForegroundColor Yellow
try {
    $wslList = wsl --list --verbose 2>&1
    if ($wslList -match "docker-desktop") {
        Write-Host "  ⚠️  Found docker-desktop WSL2 distro" -ForegroundColor Yellow
        Write-Host "  Stopping docker-desktop distro..." -ForegroundColor Gray
        wsl -t docker-desktop 2>&1 | Out-Null
        Write-Host "  ✓ docker-desktop distro stopped" -ForegroundColor Green
    } else {
        Write-Host "  ✓ No docker-desktop WSL2 distro found" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Error checking WSL2: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Docker Desktop processes stopped" -ForegroundColor Green
Write-Host "✓ Docker service stopped and disabled" -ForegroundColor Green
Write-Host ""
Write-Host "Docker Desktop will NOT start automatically on boot." -ForegroundColor Cyan
Write-Host ""


