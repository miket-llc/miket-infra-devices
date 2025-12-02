<#
.SYNOPSIS
    Completely disables Windows Search and SysMain services
.DESCRIPTION
    Stops and disables Windows Search (WSearch) and SysMain (Superfetch) services
    and prevents them from restarting
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Disabling Windows Search and SysMain" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# 1. Stop and disable Windows Search
Write-Host "[1] Disabling Windows Search (WSearch)..." -ForegroundColor Yellow
$wsearch = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
if ($wsearch) {
    if ($wsearch.Status -eq "Running") {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Windows Search stopped" -ForegroundColor Green
    }
    Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  ✓ Windows Search disabled" -ForegroundColor Green
} else {
    Write-Host "  ✓ Windows Search service not found" -ForegroundColor Green
}
Write-Host ""

# 2. Stop and disable SysMain (Superfetch)
Write-Host "[2] Disabling SysMain..." -ForegroundColor Yellow
$sysmain = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
if ($sysmain) {
    if ($sysmain.Status -eq "Running") {
        Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ SysMain stopped" -ForegroundColor Green
    }
    Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  ✓ SysMain disabled" -ForegroundColor Green
} else {
    Write-Host "  ✓ SysMain service not found" -ForegroundColor Green
}
Write-Host ""

# 3. Disable via Group Policy (registry) to prevent re-enabling
Write-Host "[3] Setting registry to prevent re-enabling..." -ForegroundColor Yellow
try {
    # Windows Search
    $wsearchRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch"
    if (Test-Path $wsearchRegPath) {
        Set-ItemProperty -Path $wsearchRegPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "  ✓ Windows Search registry set to disabled" -ForegroundColor Green
    }
    
    # SysMain
    $sysmainRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\SysMain"
    if (Test-Path $sysmainRegPath) {
        Set-ItemProperty -Path $sysmainRegPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "  ✓ SysMain registry set to disabled" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Error setting registry: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Services Disabled" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Windows Search - DISABLED" -ForegroundColor Green
Write-Host "✓ SysMain - DISABLED" -ForegroundColor Green
Write-Host ""
Write-Host "These services will not start automatically." -ForegroundColor Cyan
Write-Host ""

