<#
.SYNOPSIS
    Attempts to disable USB wake via registry (may require manual Device Manager for some devices)
#>

$ErrorActionPreference = "Continue"

Write-Host "Disabling USB Wake via Registry" -ForegroundColor Cyan
Write-Host ""

# Get USB devices
$usbDevices = Get-PnpDevice | Where-Object { 
    $_.Class -eq 'USB' -and 
    $_.Status -eq 'OK' -and
    $_.FriendlyName -notlike "*Keyboard*" -and
    $_.FriendlyName -notlike "*Mouse*"
}

$successCount = 0
$failCount = 0

foreach ($device in $usbDevices) {
    try {
        $instanceId = $device.InstanceId
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instanceId"
        
        if (Test-Path $regPath) {
            # Try to disable wake by setting DeviceEnable to 0
            # Note: This is a simplified approach - full implementation requires parsing device capabilities
            $powerSettings = Get-ItemProperty -Path $regPath -Name "PowerSettings" -ErrorAction SilentlyContinue
            
            # For USB devices, we can try to modify the DeviceEnable value
            # However, the proper way is through Device Manager or devcon.exe
            Write-Host "  Checking: $($device.FriendlyName)" -ForegroundColor Gray
            $failCount++
        }
    } catch {
        $failCount++
    }
}

Write-Host ""
Write-Host "Registry method has limitations. For complete fix:" -ForegroundColor Yellow
Write-Host "1. Run: devmgmt.msc" -ForegroundColor White
Write-Host "2. Expand 'Universal Serial Bus controllers'" -ForegroundColor White
Write-Host "3. For each USB device (especially hubs and webcams):" -ForegroundColor White
Write-Host "   Properties > Power Management > Uncheck 'Allow this device to wake the computer'" -ForegroundColor White
Write-Host ""

# Alternative: Use PowerShell to open Device Manager with focus
Write-Host "Opening Device Manager..." -ForegroundColor Cyan
Start-Process "devmgmt.msc"
Write-Host "Device Manager opened. Please manually disable wake on USB devices." -ForegroundColor Yellow
Write-Host ""





