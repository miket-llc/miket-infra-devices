<#
.SYNOPSIS
    Fixes fan cycling by stopping unnecessary services and processes
.DESCRIPTION
    Stops Windows Search indexing, Superfetch, and addresses high CPU processes
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fixing Fan Cycling Issues" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# 1. Stop Windows Search (indexing)
Write-Host "[1] Stopping Windows Search (indexing)..." -ForegroundColor Yellow
$wsearch = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
if ($wsearch -and $wsearch.Status -eq "Running") {
    Stop-Service -Name "WSearch" -Force
    Set-Service -Name "WSearch" -StartupType Disabled
    Write-Host "  ✓ Windows Search stopped and disabled" -ForegroundColor Green
} else {
    Write-Host "  ✓ Windows Search already stopped" -ForegroundColor Green
}
Write-Host ""

# 2. Stop SysMain (Superfetch)
Write-Host "[2] Stopping SysMain (Superfetch)..." -ForegroundColor Yellow
$sysmain = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
if ($sysmain -and $sysmain.Status -eq "Running") {
    Stop-Service -Name "SysMain" -Force
    Set-Service -Name "SysMain" -StartupType Disabled
    Write-Host "  ✓ SysMain stopped and disabled" -ForegroundColor Green
} else {
    Write-Host "  ✓ SysMain already stopped" -ForegroundColor Green
}
Write-Host ""

# 3. Check WSL2 podman-machine
Write-Host "[3] Checking WSL2 podman-machine..." -ForegroundColor Yellow
$wslList = wsl --list --verbose 2>&1
if ($wslList -match "podman-machine.*Running") {
    Write-Host "  ⚠️  podman-machine-default is running" -ForegroundColor Yellow
    Write-Host "  This uses memory and CPU. Stop if not needed:" -ForegroundColor Gray
    Write-Host "    wsl --shutdown" -ForegroundColor White
    Write-Host "  Or stop just podman-machine:" -ForegroundColor Gray
    Write-Host "    wsl -t podman-machine-default" -ForegroundColor White
} else {
    Write-Host "  ✓ podman-machine not running" -ForegroundColor Green
}
Write-Host ""

# 4. Check for high CPU WmiPrvSE processes
Write-Host "[4] Checking WmiPrvSE processes..." -ForegroundColor Yellow
$wmiProcs = Get-Process -Name "WmiPrvSE" -ErrorAction SilentlyContinue
if ($wmiProcs) {
    $totalCPU = ($wmiProcs | Measure-Object -Property CPU -Sum).Sum
    $procCount = $wmiProcs.Count
    $cpuRounded = [math]::Round($totalCPU, 2)
    Write-Host "  Found $procCount WmiPrvSE process(es) with $cpuRounded CPU seconds" -ForegroundColor Yellow
    Write-Host "  WmiPrvSE is Windows Management Instrumentation" -ForegroundColor Gray
    Write-Host "  High CPU usually indicates monitoring/management tools querying system" -ForegroundColor Gray
    Write-Host "  These will restart automatically if needed" -ForegroundColor Gray
    Write-Host "  Consider stopping if not needed:" -ForegroundColor Yellow
    Write-Host "    Stop-Process -Name WmiPrvSE -Force" -ForegroundColor White
} else {
    Write-Host "  ✓ No WmiPrvSE processes found" -ForegroundColor Green
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Windows Search stopped and disabled" -ForegroundColor Green
Write-Host "✓ SysMain (Superfetch) stopped and disabled" -ForegroundColor Green
Write-Host ""
Write-Host "These changes should reduce fan cycling." -ForegroundColor Cyan
Write-Host "If WSL2 podman-machine is not needed, stop it to free memory." -ForegroundColor Yellow
Write-Host ""

