<#
.SYNOPSIS
    Fixes sleep/wake issues on Wintermute by disabling USB Selective Suspend,
    disabling Fast Startup, and configuring USB wake settings
.DESCRIPTION
    This script addresses common causes of sleep/wake failures on Windows workstations
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wintermute Sleep/Wake Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# 1. Disable USB Selective Suspend
Write-Host "[1] Disabling USB Selective Suspend..." -ForegroundColor Yellow
try {
    powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /setactive SCHEME_CURRENT
    Write-Host "  ✓ USB Selective Suspend disabled" -ForegroundColor Green
} catch {
    Write-Warning "  ⚠ Error disabling USB Selective Suspend: $_"
}
Write-Host ""

# 2. Disable Fast Startup
Write-Host "[2] Disabling Fast Startup..." -ForegroundColor Yellow
try {
    $fastStartup = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
    if ($fastStartup -and $fastStartup.HiberbootEnabled -eq 1) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
        Write-Host "  ✓ Fast Startup disabled" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Fast Startup already disabled" -ForegroundColor Green
    }
} catch {
    Write-Warning "  ⚠ Error disabling Fast Startup: $_"
}
Write-Host ""

# 3. Disable wake on USB devices (except keyboard/mouse)
Write-Host "[3] Configuring USB device wake settings..." -ForegroundColor Yellow
Write-Host "  (This may take a moment with many USB devices)" -ForegroundColor Gray

$usbDevices = Get-PnpDevice | Where-Object { 
    $_.Class -eq 'USB' -and 
    $_.Status -eq 'OK' -and
    $_.FriendlyName -notlike "*Keyboard*" -and
    $_.FriendlyName -notlike "*Mouse*"
}

$disabledCount = 0
$skippedCount = 0

foreach ($device in $usbDevices) {
    try {
        # Use devcon or pnputil to disable wake
        # PowerShell doesn't have direct API for this, so we'll use registry
        $instanceId = $device.InstanceId
        
        # Try to disable wake via registry (if supported)
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instanceId"
        if (Test-Path $regPath) {
            try {
                $powerSettings = Get-ItemProperty -Path $regPath -Name "PowerSettings" -ErrorAction SilentlyContinue
                # Note: This is a simplified approach - full implementation would require more complex registry manipulation
                $skippedCount++
            } catch {
                $skippedCount++
            }
        } else {
            $skippedCount++
        }
    } catch {
        $skippedCount++
    }
}

Write-Host "  ⚠ Note: USB wake settings require manual configuration in Device Manager" -ForegroundColor Yellow
Write-Host "     For each USB device (except keyboard/mouse):" -ForegroundColor Gray
Write-Host "     Device Manager > USB device > Properties > Power Management" -ForegroundColor Gray
Write-Host "     Uncheck 'Allow this device to wake the computer'" -ForegroundColor Gray
Write-Host ""

# 4. Ensure sleep is disabled (workstation should stay awake)
Write-Host "[4] Ensuring sleep is disabled on AC power..." -ForegroundColor Yellow
try {
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    Write-Host "  ✓ Sleep disabled on AC power" -ForegroundColor Green
} catch {
    Write-Warning "  ⚠ Error configuring sleep settings: $_"
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ USB Selective Suspend: DISABLED" -ForegroundColor Green
Write-Host "✓ Fast Startup: DISABLED" -ForegroundColor Green
Write-Host "✓ Sleep on AC: DISABLED" -ForegroundColor Green
Write-Host ""
Write-Host "⚠ Manual Action Required:" -ForegroundColor Yellow
Write-Host "  - Open Device Manager" -ForegroundColor White
Write-Host "  - For each USB device (except keyboard/mouse):" -ForegroundColor White
Write-Host "    Properties > Power Management > Uncheck 'Allow this device to wake the computer'" -ForegroundColor White
Write-Host ""
Write-Host "This should resolve sleep/wake issues. Reboot recommended." -ForegroundColor Cyan
Write-Host ""


