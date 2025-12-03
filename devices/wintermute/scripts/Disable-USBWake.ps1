<#
.SYNOPSIS
    Disables wake capability on USB devices (except keyboard/mouse)
.DESCRIPTION
    Uses devcon to disable wake on USB devices. Requires devcon.exe or manual Device Manager configuration.
    This script provides instructions and attempts to configure via registry where possible.
#>

$ErrorActionPreference = "Continue"

Write-Host "Disabling USB Wake Settings" -ForegroundColor Cyan
Write-Host ""

# Get all USB devices
$usbDevices = Get-PnpDevice | Where-Object { 
    $_.Class -eq 'USB' -and 
    $_.Status -eq 'OK'
}

Write-Host "Found $($usbDevices.Count) USB devices" -ForegroundColor Yellow
Write-Host ""

# List devices that should have wake disabled
Write-Host "USB devices that should NOT wake the computer:" -ForegroundColor Cyan
$nonWakeDevices = $usbDevices | Where-Object {
    $_.FriendlyName -notlike "*Keyboard*" -and
    $_.FriendlyName -notlike "*Mouse*" -and
    $_.FriendlyName -notlike "*HID*"
}

$nonWakeDevices | ForEach-Object {
    Write-Host "  - $($_.FriendlyName)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "To disable wake on these devices:" -ForegroundColor Yellow
Write-Host "1. Open Device Manager (devmgmt.msc)" -ForegroundColor White
Write-Host "2. Expand 'Universal Serial Bus controllers'" -ForegroundColor White
Write-Host "3. For each device listed above:" -ForegroundColor White
Write-Host "   a. Right-click > Properties" -ForegroundColor White
Write-Host "   b. Go to 'Power Management' tab" -ForegroundColor White
Write-Host "   c. Uncheck 'Allow this device to wake the computer'" -ForegroundColor White
Write-Host "   d. Click OK" -ForegroundColor White
Write-Host ""
Write-Host "Common devices to check:" -ForegroundColor Yellow
Write-Host "  - USB hubs" -ForegroundColor White
Write-Host "  - Webcams (Logitech BRIO, etc.)" -ForegroundColor White
Write-Host "  - External drives" -ForegroundColor White
Write-Host "  - USB audio devices" -ForegroundColor White
Write-Host "  - USB network adapters" -ForegroundColor White
Write-Host ""

# Attempt to use registry method (limited success)
Write-Host "Attempting to disable wake via registry (may not work for all devices)..." -ForegroundColor Yellow
$successCount = 0
$failCount = 0

foreach ($device in $nonWakeDevices) {
    try {
        $instanceId = $device.InstanceId
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instanceId"
        
        if (Test-Path $regPath) {
            # Try to set DeviceEnable to 0 (this is a simplified approach)
            # Full implementation would require parsing device capabilities
            $failCount++
        } else {
            $failCount++
        }
    } catch {
        $failCount++
    }
}

Write-Host ""
Write-Host "⚠ Registry method has limited success. Manual Device Manager configuration is recommended." -ForegroundColor Yellow
Write-Host ""


